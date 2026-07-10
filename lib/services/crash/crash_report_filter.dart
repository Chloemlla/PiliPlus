abstract final class CrashReportFilter {
  static bool shouldIgnore(Object error) {
    final message = error.toString().trim().toLowerCase();
    if (message.isEmpty) return false;

    return _ignoredMessageFragments.any(message.contains);
  }

  static const _ignoredMessageFragments = <String>[
    'ssl seek failed',
    'failed to open https://',
    'can not open external file https://',
    'tcp: ffurl_read returned ',
    'https: stream ends prematurely',
    'http: stream ends prematurely',
  ];
}
