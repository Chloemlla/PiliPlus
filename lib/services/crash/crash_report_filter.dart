import 'package:pili_plus/services/crash/crash_report.dart';

abstract final class CrashReportFilter {
  static bool shouldIgnore(Object error, [StackTrace? stackTrace]) {
    if (_isHttp2GoawayAfterWriterClose(error, stackTrace)) return true;
    if (error is String && !_hasUsefulStack(stackTrace)) return true;

    final message = error.toString().trim().toLowerCase();
    if (message.isEmpty) return false;

    final knownDiagnostic =
        _sslSeekFailure.hasMatch(message) ||
        _ignoredMessageFragments.any(message.contains);
    if (!knownDiagnostic) return false;
    if (error is! String && _hasApplicationStack(stackTrace)) return false;
    return true;
  }

  /// System/device faults that stay in crash history but are not surfaced as
  /// fatal. Matches a native crash whose stack is entirely inside Android's
  /// hardware-UI shader disk cache writer (libhwui.so `ShaderCache::store`
  /// deferred-save thread) — a firmware/driver-level SIGSEGV (seen on
  /// MediaTek/Mali + Android 16, e.g. vivo V2426A), never an app frame.
  static bool isKnownDeviceIssue(CrashReport report) {
    if (report.reason != 'native_crash') return false;
    final stack = report.stackTrace.toLowerCase();
    return stack.contains('shadercache::store') && stack.contains('libhwui');
  }

  static bool _hasUsefulStack(StackTrace? stackTrace) =>
      stackTrace?.toString().trim().isNotEmpty ?? false;

  static bool _hasApplicationStack(StackTrace? stackTrace) =>
      stackTrace?.toString().contains('package:pili_plus/') ?? false;

  static bool _isHttp2GoawayAfterWriterClose(
    Object error,
    StackTrace? stackTrace,
  ) {
    if (error is! StateError ||
        error.toString().trim() !=
            'Bad state: Cannot add event after closing') {
      return false;
    }
    final stack = stackTrace?.toString() ?? '';
    return stack.contains('package:http2/src/frames/frame_writer.dart') &&
        stack.contains('FrameWriter.writeGoawayFrame') &&
        stack.contains(
          'package:http2/src/flowcontrol/connection_queues.dart',
        ) &&
        !stack.contains('package:pili_plus/');
  }

  static final _sslSeekFailure = RegExp(r'\bssl\b.{0,32}\bseek failed\b');

  static const _ignoredMessageFragments = <String>[
    'ssl seek failed',
    'failed to open https://',
    'can not open external file https://',
    'seek failed (to ',
    'tcp: connection to tcp://',
    'tcp: failed to resolve hostname ',
    'tcp: ffurl_read returned ',
    'tcp: ffurl_write returned ',
    'tls: mbedtls_ssl_',
    'https: stream ends prematurely',
    'http: stream ends prematurely',
    'amediacodec:',
    'missing picture in access unit',
    'invalid nal unit size',
    'unsupported format for accessing property',
  ];
}
