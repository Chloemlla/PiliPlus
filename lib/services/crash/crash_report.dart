import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/services/crash/crash_breadcrumbs.dart';
import 'package:pili_plus/utils/log_redactor.dart';
import 'package:crypto/crypto.dart';

class CrashReport {
  final String reportId;
  final int crashedAtMillis;
  final String crashedAtText;
  final String exceptionType;
  final String rootCause;
  final String threadName;
  final String processName;
  final String systemInfo;
  final String stackTrace;
  final List<String> recentEvents;

  const CrashReport({
    required this.reportId,
    required this.crashedAtMillis,
    required this.crashedAtText,
    required this.exceptionType,
    required this.rootCause,
    required this.threadName,
    required this.processName,
    required this.systemInfo,
    required this.stackTrace,
    this.recentEvents = const [],
  });

  factory CrashReport.fromError(
    Object error,
    StackTrace? stackTrace, {
    String? systemInfo,
  }) {
    final now = DateTime.now();
    final crashedAtMillis = now.millisecondsSinceEpoch;
    final exceptionType = error.runtimeType.toString();
    final rootCause = _sanitize(error.toString().trim().isEmpty
        ? exceptionType
        : error.toString());
    final stackTraceText = _sanitize(stackTrace?.toString() ?? '');
    return CrashReport(
      reportId: _reportId(
        crashedAtMillis,
        exceptionType,
        rootCause,
        stackTraceText,
      ),
      crashedAtMillis: crashedAtMillis,
      crashedAtText: _formatDateTime(now),
      exceptionType: exceptionType,
      rootCause: rootCause,
      threadName: Isolate.current.debugName ?? 'main',
      processName: 'pid:$pid',
      systemInfo: systemInfo ?? CrashReportSystemInfo.cached,
      stackTrace: stackTraceText,
      recentEvents: CrashBreadcrumbs.snapshot(),
    );
  }

  factory CrashReport.fromJson(Map<String, dynamic> json) {
    return CrashReport(
      reportId: (json['reportId'] as String?)?.trim().isNotEmpty == true
          ? json['reportId'] as String
          : (json['crashedAtMillis'] as num).toInt().toString().padLeft(12),
      crashedAtMillis: (json['crashedAtMillis'] as num).toInt(),
      crashedAtText: json['crashedAtText'] as String,
      exceptionType: json['exceptionType'] as String,
      rootCause: json['rootCause'] as String,
      threadName: json['threadName'] as String? ?? 'unknown',
      processName: json['processName'] as String? ?? 'unknown',
      systemInfo: json['systemInfo'] as String,
      stackTrace: json['stackTrace'] as String,
      recentEvents: [
        for (final event in json['recentEvents'] as List<dynamic>? ?? const [])
          if (event.toString().trim().isNotEmpty) event.toString(),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'reportId': reportId,
        'crashedAtMillis': crashedAtMillis,
        'crashedAtText': crashedAtText,
        'exceptionType': exceptionType,
        'rootCause': rootCause,
        'threadName': threadName,
        'processName': processName,
        'systemInfo': systemInfo,
        'stackTrace': stackTrace,
        'recentEvents': recentEvents,
      };

  String toClipboardText() {
    final buffer = StringBuffer()
      ..writeln('Report ID: $reportId')
      ..writeln('Crash time: $crashedAtText')
      ..writeln('Exception type: $exceptionType')
      ..writeln('Root cause: $rootCause')
      ..writeln('Thread: $threadName')
      ..writeln('Process: $processName')
      ..writeln('System info:')
      ..writeln(systemInfo);
    if (recentEvents.isNotEmpty) {
      buffer.writeln('Recent app events:');
      for (final event in recentEvents) {
        buffer.writeln(event);
      }
    }
    buffer
      ..writeln('Stack trace:')
      ..writeln(stackTrace);
    return LogRedactor.redactText(buffer.toString());
  }

  static String _reportId(
    int crashedAtMillis,
    String exceptionType,
    String rootCause,
    String stackTrace,
  ) {
    final stackLines = const LineSplitter().convert(stackTrace);
    final firstStackLine = stackLines.isEmpty ? '' : stackLines.first;
    final seed = '$crashedAtMillis|$exceptionType|$rootCause|$firstStackLine';
    return sha256.convert(utf8.encode(seed)).toString().substring(0, 12);
  }

  static String _sanitize(String value) => LogRedactor.redactText(value);

  static String _formatDateTime(DateTime time) {
    return '${time.year.toString().padLeft(4, '0')}-'
        '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
}

abstract final class CrashReportSystemInfo {
  static String cached = _fallback();

  static void update(String value) {
    if (value.trim().isNotEmpty) cached = value;
  }

  static String _fallback() {
    final usedMb = ProcessInfo.currentRss ~/ _bytesPerMebibyte;
    final maxMb = ProcessInfo.maxRss ~/ _bytesPerMebibyte;
    return [
      'App version: ${BuildConfig.versionName} (${BuildConfig.versionCode})',
      'Build time: ${BuildConfig.buildTime}',
      'Commit: ${BuildConfig.commitHash}',
      'OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'Locale: ${Platform.localeName}',
      'Memory: $usedMb MiB used / $maxMb MiB max',
    ].join('\n');
  }

  static const _bytesPerMebibyte = 1024 * 1024;
}
