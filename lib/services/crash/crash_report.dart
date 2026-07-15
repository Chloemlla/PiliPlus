import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:pili_plus/build_config.dart';
import 'package:pili_plus/services/crash/crash_breadcrumbs.dart';
import 'package:pili_plus/services/crash/crash_context.dart';
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
  final CrashSource source;
  final CrashSeverity severity;
  final String sessionId;
  final String module;
  final String operation;
  final String route;
  final String reason;

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
    this.source = CrashSource.unknown,
    this.severity = CrashSeverity.unknown,
    this.sessionId = 'legacy',
    this.module = 'unknown',
    this.operation = '',
    this.route = '',
    this.reason = '',
  });

  bool get isFatalCandidate => severity.isFatalCandidate;

  CrashReport mergeWith(CrashReport other) {
    final preferred = _severityRank(other.severity) > _severityRank(severity)
        ? other
        : this;
    final secondary = identical(preferred, this) ? other : this;
    String choose(String preferredValue, String fallback, {String empty = ''}) {
      return preferredValue != empty ? preferredValue : fallback;
    }

    return CrashReport(
      reportId: reportId,
      crashedAtMillis: crashedAtMillis <= other.crashedAtMillis
          ? crashedAtMillis
          : other.crashedAtMillis,
      crashedAtText: crashedAtMillis <= other.crashedAtMillis
          ? crashedAtText
          : other.crashedAtText,
      exceptionType: exceptionType,
      rootCause: rootCause,
      threadName: choose(
        preferred.threadName,
        secondary.threadName,
        empty: 'unknown',
      ),
      processName: choose(
        preferred.processName,
        secondary.processName,
        empty: 'unknown',
      ),
      systemInfo: other.systemInfo.length >= systemInfo.length
          ? other.systemInfo
          : systemInfo,
      stackTrace: other.stackTrace.length > stackTrace.length
          ? other.stackTrace
          : stackTrace,
      recentEvents: other.recentEvents.length > recentEvents.length
          ? other.recentEvents
          : recentEvents,
      source: preferred.source != CrashSource.unknown
          ? preferred.source
          : secondary.source,
      severity: preferred.severity,
      sessionId: choose(
        preferred.sessionId,
        secondary.sessionId,
        empty: 'legacy',
      ),
      module: choose(preferred.module, secondary.module, empty: 'unknown'),
      operation: choose(preferred.operation, secondary.operation),
      route: choose(preferred.route, secondary.route),
      reason: choose(preferred.reason, secondary.reason),
    );
  }

  factory CrashReport.fromError(
    Object error,
    StackTrace? stackTrace, {
    String? systemInfo,
    CrashSource source = CrashSource.explicit,
    CrashSeverity severity = CrashSeverity.handled,
    String sessionId = 'legacy',
    String? module,
    String operation = '',
    String route = '',
    String reason = '',
  }) {
    final now = DateTime.now();
    final crashedAtMillis = now.millisecondsSinceEpoch;
    final exceptionType = error.runtimeType.toString();
    final rootCause = _sanitize(
      error.toString().trim().isEmpty ? exceptionType : error.toString(),
    );
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
      threadName: _context(Isolate.current.debugName, 'main'),
      processName: 'pid:$pid',
      systemInfo: _sanitize(systemInfo ?? CrashReportSystemInfo.cached),
      stackTrace: stackTraceText,
      recentEvents: CrashBreadcrumbs.snapshot(),
      source: source,
      severity: severity,
      sessionId: _context(sessionId, 'legacy'),
      module: _context(
        module ?? CrashModuleResolver.fromStack(stackTrace),
        'unknown',
      ),
      operation: _context(operation, ''),
      route: _context(route, ''),
      reason: _context(reason, ''),
    );
  }

  factory CrashReport.fromNative(
    Map<String, dynamic> json, {
    required String systemInfo,
  }) {
    final crashedAtMillis =
        (json['timestamp'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    final exceptionType = _text(json['exceptionType'], 'NativeCrash');
    final rootCause = _sanitize(_text(json['message'], exceptionType));
    final stackTrace = _sanitize(_text(json['stackTrace'], ''));
    final source = CrashSource.parse(json['source']);
    final processName = _text(
      json['processName'],
      'pid:${(json['pid'] as num?)?.toInt() ?? 0}',
    );
    final recentEvents = [
      for (final event in json['recentEvents'] as List<dynamic>? ?? const [])
        if (event.toString().trim().isNotEmpty)
          _context(event, '', maxLength: 180),
    ];
    final capturedSystemInfo = _text(json['systemInfo'], '');
    final nativeInfo = _sanitize(
      <String>[
        systemInfo,
        if (capturedSystemInfo.isNotEmpty) capturedSystemInfo,
        'Captured app: ${_text(json['appVersion'], 'unknown')}',
        'Captured Android: ${_text(json['androidRelease'], 'unknown')} '
            '(SDK ${json['sdk'] ?? 'unknown'})',
        'Captured device: ${_text(json['manufacturer'], 'unknown')} '
            '${_text(json['model'], 'unknown')}',
        'Captured fingerprint: ${_text(json['fingerprint'], 'unknown')}',
        if (json['authorName'] != null)
          'Crash SDK author: ${_text(json['authorName'], 'unknown')}',
        if (json['authorUrl'] != null)
          'Crash SDK author URL: ${_text(json['authorUrl'], 'unknown')}',
        if (json['authorFingerprint'] != null)
          'Crash SDK fingerprint: ${_text(json['authorFingerprint'], 'unknown')}',
        if (json['capture'] != null) 'Capture path: ${_text(json['capture'], 'unknown')}',
        if (json['status'] != null) 'Exit status: ${json['status']}',
        if (json['importance'] != null)
          'Exit importance: ${json['importance']}',
        if (json['pss'] != null) 'Exit PSS: ${json['pss']}',
        if (json['rss'] != null) 'Exit RSS: ${json['rss']}',
      ].join('\n'),
    );
    return CrashReport(
      reportId: () {
        final provided = json['reportId']?.toString().trim();
        if (provided != null && provided.isNotEmpty) return provided;
        final recordId = json['recordId']?.toString().trim();
        // Prefer lumen-crash report IDs; keep generated IDs for exit staging files.
        if (recordId != null &&
            recordId.isNotEmpty &&
            json['capture']?.toString() == 'lumen_crash') {
          return recordId;
        }
        return _reportId(
          crashedAtMillis,
          exceptionType,
          rootCause,
          stackTrace,
        );
      }(),
      crashedAtMillis: crashedAtMillis,
      crashedAtText: _formatDateTime(
        DateTime.fromMillisecondsSinceEpoch(crashedAtMillis),
      ),
      exceptionType: exceptionType,
      rootCause: rootCause,
      threadName: _text(json['threadName'], 'unknown'),
      processName: processName,
      systemInfo: nativeInfo,
      stackTrace: stackTrace,
      recentEvents: recentEvents,
      source: source,
      severity: CrashSeverity.parse(json['severity']),
      sessionId: _context('native:$processName:$crashedAtMillis', 'native'),
      module: _context(json['module'], 'android'),
      reason: _context(json['reason'], 'native_failure'),
    );
  }

  factory CrashReport.fromJson(Map<String, dynamic> json) {
    return CrashReport(
      reportId: (json['reportId'] as String?)?.trim().isNotEmpty == true
          ? json['reportId'] as String
          : (json['crashedAtMillis'] as num).toInt().toString().padLeft(12),
      crashedAtMillis: (json['crashedAtMillis'] as num).toInt(),
      crashedAtText: json['crashedAtText'] as String,
      exceptionType: _context(json['exceptionType'], 'unknown'),
      rootCause: _sanitize(json['rootCause'] as String),
      threadName: _context(json['threadName'], 'unknown'),
      processName: _context(json['processName'], 'unknown'),
      systemInfo: _sanitize(json['systemInfo'] as String),
      stackTrace: _sanitize(json['stackTrace'] as String),
      recentEvents: [
        for (final event in json['recentEvents'] as List<dynamic>? ?? const [])
          if (event.toString().trim().isNotEmpty)
            _context(event, '', maxLength: 180),
      ],
      source: CrashSource.parse(json['source']),
      severity: CrashSeverity.parse(json['severity']),
      sessionId: _context(json['sessionId'], 'legacy'),
      module: _context(json['module'], 'unknown'),
      operation: _context(json['operation'], ''),
      route: _context(json['route'], ''),
      reason: _context(json['reason'], ''),
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
    'source': source.value,
    'severity': severity.value,
    'sessionId': sessionId,
    'module': module,
    'operation': operation,
    'route': route,
    'reason': reason,
  };

  String toClipboardText() {
    final buffer = StringBuffer()
      ..writeln('Report ID: $reportId')
      ..writeln('Crash time: $crashedAtText')
      ..writeln('Exception type: $exceptionType')
      ..writeln('Root cause: $rootCause')
      ..writeln('Thread: $threadName')
      ..writeln('Process: $processName')
      ..writeln('Source: ${source.label} (${source.value})')
      ..writeln('Severity: ${severity.label} (${severity.value})')
      ..writeln('Module: $module')
      ..writeln('Operation: ${operation.isEmpty ? 'unknown' : operation}')
      ..writeln('Route: ${route.isEmpty ? 'unknown' : route}')
      ..writeln('Reason: ${reason.isEmpty ? 'unknown' : reason}')
      ..writeln('Session: $sessionId')
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

  static int _severityRank(CrashSeverity value) => switch (value) {
    CrashSeverity.fatal => 4,
    CrashSeverity.unhandled => 3,
    CrashSeverity.handled => 2,
    CrashSeverity.diagnostic => 1,
    CrashSeverity.unknown => 0,
  };

  static String _text(Object? value, String fallback) {
    return _context(value, fallback, maxLength: 4096);
  }

  static String _context(
    Object? value,
    String fallback, {
    int maxLength = 512,
  }) {
    final text = _sanitize(value?.toString().trim() ?? '');
    final resolved = text.isEmpty ? fallback : text;
    return resolved.length <= maxLength
        ? resolved
        : resolved.substring(0, maxLength);
  }

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
