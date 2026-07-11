abstract final class CrashReportFilter {
  static bool shouldIgnore(Object error, [StackTrace? stackTrace]) {
    if (error is String && !_hasUsefulStack(stackTrace)) return true;

    final message = error.toString().trim().toLowerCase();
    if (message.isEmpty) return false;

    return _sslSeekFailure.hasMatch(message) ||
        _ignoredMessageFragments.any(message.contains);
  }

  static bool _hasUsefulStack(StackTrace? stackTrace) =>
      stackTrace?.toString().trim().isNotEmpty ?? false;

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
