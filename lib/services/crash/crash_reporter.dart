import 'dart:io';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/services/crash/crash_breadcrumbs.dart';
import 'package:pili_plus/services/crash/crash_context.dart';
import 'package:pili_plus/services/crash/crash_report.dart';
import 'package:pili_plus/services/crash/crash_report_filter.dart';
import 'package:pili_plus/services/crash/crash_report_store.dart';
import 'package:pili_plus/services/crash/native_crash_bridge.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

abstract final class CrashReporter {
  static bool _installed = false;
  static FlutterExceptionHandler? _installedFlutterErrorHandler;
  static ErrorCallback? _installedPlatformErrorHandler;
  static final List<CrashReport> _bufferedReports = [];
  static final String sessionId =
      '$pid-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  static bool shouldIgnore(Object error, [StackTrace? stackTrace]) =>
      CrashReportFilter.shouldIgnore(error, stackTrace);

  static Future<CrashReport?> ensureInitialized() async {
    await CrashReportStore.ensureInitialized();
    _flushBufferedReports();
    try {
      CrashReportSystemInfo.update(await _buildSystemInfo());
    } catch (error) {
      CrashBreadcrumbs.record(
        'Crash system info unavailable: ${error.runtimeType}',
      );
      if (kDebugMode) debugPrint('Crash system info collection failed: $error');
    }
    await _importNativeReports();
    final pending = CrashReportStore.load();
    if (pending == null) return null;
    if (!pending.isFatalCandidate || pending.sessionId == sessionId) {
      await CrashReportStore.markSeen(pending.reportId);
      return null;
    }
    return pending;
  }

  static void install({bool force = false}) {
    if (_installed && !force) return;
    if (_installed &&
        FlutterError.onError == _installedFlutterErrorHandler &&
        PlatformDispatcher.instance.onError == _installedPlatformErrorHandler) {
      return;
    }
    _installed = true;
    final installedFlutterErrorHandler = _installedFlutterErrorHandler;
    final installedPlatformErrorHandler = _installedPlatformErrorHandler;
    final currentFlutterErrorHandler = FlutterError.onError;
    final currentPlatformErrorHandler = PlatformDispatcher.instance.onError;
    final previousFlutterErrorHandler =
        currentFlutterErrorHandler == installedFlutterErrorHandler
        ? null
        : currentFlutterErrorHandler;
    final previousPlatformErrorHandler =
        currentPlatformErrorHandler == installedPlatformErrorHandler
        ? null
        : currentPlatformErrorHandler;

    late final FlutterExceptionHandler flutterHandler;
    flutterHandler = (details) {
      final stackModule = CrashModuleResolver.fromStack(details.stack);
      recordErrorSync(
        details.exception,
        details.stack,
        source: CrashSource.flutterFramework,
        severity: CrashSeverity.unhandled,
        module: stackModule == 'unknown' ? details.library : stackModule,
        operation: details.context?.toDescription() ?? '',
      );
      final previous = previousFlutterErrorHandler;
      if (previous != null && previous != flutterHandler) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    _installedFlutterErrorHandler = flutterHandler;
    FlutterError.onError = flutterHandler;

    late final ErrorCallback platformHandler;
    platformHandler = (error, stackTrace) {
      var handled = false;
      try {
        handled =
            previousPlatformErrorHandler?.call(error, stackTrace) ?? false;
        return handled;
      } finally {
        recordErrorSync(
          error,
          stackTrace,
          source: CrashSource.platformDispatcher,
          severity: CrashSeverity.fromPlatformHandled(handled),
        );
      }
    };
    _installedPlatformErrorHandler = platformHandler;
    PlatformDispatcher.instance.onError = platformHandler;

    CrashBreadcrumbs.record('Crash reporter installed');
  }

  static CrashReport recordErrorSync(
    Object error,
    StackTrace? stackTrace, {
    CrashSource source = CrashSource.explicit,
    CrashSeverity severity = CrashSeverity.handled,
    String? module,
    String operation = '',
    String reason = '',
  }) {
    if (!severity.isFatalCandidate && shouldIgnore(error, stackTrace)) {
      CrashBreadcrumbs.record('Crash ignored: ${error.runtimeType}');
      return CrashReport.fromError(
        error,
        stackTrace,
        source: source,
        severity: CrashSeverity.diagnostic,
        sessionId: sessionId,
        module: module,
        operation: operation,
        route: CrashBreadcrumbNavigatorObserver.currentRoute,
        reason: reason,
      );
    }
    CrashBreadcrumbs.record('Crash captured: ${error.runtimeType}');
    final report = CrashReport.fromError(
      error,
      stackTrace,
      source: source,
      severity: severity,
      sessionId: sessionId,
      module: module,
      operation: operation,
      route: CrashBreadcrumbNavigatorObserver.currentRoute,
      reason: reason,
    );
    try {
      if (CrashReportStore.isInitialized) {
        CrashReportStore.saveSync(
          report,
          makePending: severity.isFatalCandidate,
        );
      } else {
        _bufferReport(report);
      }
    } catch (e) {
      _bufferReport(report);
      if (kDebugMode) debugPrint('Crash report save failed: $e');
    }
    return report;
  }

  static Future<CrashReport> recordError(
    Object error,
    StackTrace? stackTrace, {
    CrashSource source = CrashSource.explicit,
    CrashSeverity severity = CrashSeverity.handled,
    String? module,
    String operation = '',
    String reason = '',
  }) {
    return Future.sync(
      () => recordErrorSync(
        error,
        stackTrace,
        source: source,
        severity: severity,
        module: module,
        operation: operation,
        reason: reason,
      ),
    );
  }

  static Future<void> _importNativeReports() async {
    try {
      final reports = await NativeCrashBridge.getPendingReports();
      final acknowledged = <String>[];
      for (final json in reports) {
        final recordId = json['recordId']?.toString();
        try {
          final report = CrashReport.fromNative(
            json,
            systemInfo: CrashReportSystemInfo.cached,
          );
          CrashReportStore.saveSync(report, makePending: true);
          if (recordId != null && recordId.isNotEmpty) {
            acknowledged.add(recordId);
          }
        } catch (_) {
          continue;
        }
      }
      await NativeCrashBridge.acknowledgeReports(acknowledged);
    } catch (_) {
      // Native crash import is best-effort; pending files remain for next launch.
    }
  }

  static void _flushBufferedReports() {
    while (_bufferedReports.isNotEmpty) {
      final report = _bufferedReports.first;
      try {
        CrashReportStore.saveSync(
          report,
          makePending: report.isFatalCandidate,
        );
        _bufferedReports.removeAt(0);
      } catch (error) {
        if (kDebugMode) debugPrint('Buffered crash report save failed: $error');
        break;
      }
    }
  }

  static void _bufferReport(CrashReport report) {
    if (_bufferedReports.any((item) => item.reportId == report.reportId)) {
      return;
    }
    if (_bufferedReports.length >= 8) {
      final nonFatalIndex = _bufferedReports.indexWhere(
        (item) => !item.isFatalCandidate,
      );
      _bufferedReports.removeAt(nonFatalIndex == -1 ? 0 : nonFatalIndex);
    }
    _bufferedReports.add(report);
  }

  static Future<String> _buildSystemInfo() async {
    final lines = <String>[
      'App version: ${BuildConfig.versionName} (${BuildConfig.versionCode})',
      'Build time: ${BuildConfig.buildTime}',
      'Commit: ${BuildConfig.commitHash}',
      'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'Locale: ${Platform.localeName}',
      'Memory: ${ProcessInfo.currentRss ~/ _bytesPerMebibyte} MiB used / '
          '${ProcessInfo.maxRss ~/ _bytesPerMebibyte} MiB max',
    ];
    final deviceInfo = await _deviceInfo();
    if (deviceInfo.isNotEmpty) {
      lines.addAll(deviceInfo);
    }
    return lines.join('\n');
  }

  static Future<List<String>> _deviceInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return [
          'Device: ${info.manufacturer} ${info.model}',
          'Android: ${info.version.release} (SDK ${info.version.sdkInt})',
          'ABI: ${info.supportedAbis.join(', ')}',
          'Build fingerprint: ${info.fingerprint}',
        ];
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return [
          'Device: ${info.name} ${info.model}',
          'System: ${info.systemName} ${info.systemVersion}',
        ];
      }
      if (Platform.isMacOS) {
        final info = await plugin.macOsInfo;
        return [
          'Device: ${info.computerName} ${info.model}',
          'Kernel: ${info.kernelVersion}',
        ];
      }
      if (Platform.isWindows) {
        final info = await plugin.windowsInfo;
        return [
          'Device: ${info.computerName}',
          'Windows build: ${info.buildNumber}',
        ];
      }
      if (Platform.isLinux) {
        final info = await plugin.linuxInfo;
        return [
          'Device: ${info.prettyName}',
          'Machine: ${info.machineId ?? 'unknown'}',
        ];
      }
    } catch (e) {
      return ['Device info unavailable: ${e.runtimeType}'];
    }
    return const [];
  }

  static const _bytesPerMebibyte = 1024 * 1024;
}
