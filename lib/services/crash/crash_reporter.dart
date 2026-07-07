import 'dart:io';
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/services/crash/crash_breadcrumbs.dart';
import 'package:pili_plus/services/crash/crash_report.dart';
import 'package:pili_plus/services/crash/crash_report_store.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

abstract final class CrashReporter {
  static FlutterExceptionHandler? _previousFlutterErrorHandler;
  static ErrorCallback? _previousPlatformErrorHandler;
  static bool _installed = false;

  static Future<CrashReport?> ensureInitialized() async {
    await CrashReportStore.ensureInitialized();
    CrashReportSystemInfo.update(await _buildSystemInfo());
    return CrashReportStore.load();
  }

  static void install() {
    if (_installed) return;
    _installed = true;
    _previousFlutterErrorHandler = FlutterError.onError;
    _previousPlatformErrorHandler = PlatformDispatcher.instance.onError;

    FlutterError.onError = (details) {
      recordErrorSync(details.exception, details.stack);
      final previous = _previousFlutterErrorHandler;
      if (previous != null && previous != FlutterError.onError) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      recordErrorSync(error, stackTrace);
      final previous = _previousPlatformErrorHandler;
      if (previous != null && previous != PlatformDispatcher.instance.onError) {
        return previous(error, stackTrace);
      }
      return false;
    };

    CrashBreadcrumbs.record('Crash reporter installed');
  }

  static CrashReport recordErrorSync(Object error, StackTrace? stackTrace) {
    CrashBreadcrumbs.record('Crash captured: ${error.runtimeType}');
    final report = CrashReport.fromError(error, stackTrace);
    try {
      CrashReportStore.saveSync(report);
    } catch (e) {
      if (kDebugMode) debugPrint('Crash report save failed: $e');
    }
    return report;
  }

  static Future<CrashReport> recordError(
    Object error,
    StackTrace? stackTrace,
  ) async {
    return recordErrorSync(error, stackTrace);
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
