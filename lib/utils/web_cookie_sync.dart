import 'dart:io' show Cookie;

typedef WebCookieWriter = Future<void> Function(Uri origin, Cookie cookie);

abstract final class WebCookieSync {
  static final Uri origin = Uri.https('www.bilibili.com', '/');

  static Future<void> writeAll(
    Iterable<Cookie> cookies, {
    required WebCookieWriter write,
  }) async {
    await Future.wait(
      cookies.map((cookie) async {
        try {
          await write(origin, cookie);
        } catch (error, stackTrace) {
          Error.throwWithStackTrace(
            StateError(
              'Failed to sync WebView cookie ${cookie.name}: '
              '${error.runtimeType}',
            ),
            stackTrace,
          );
        }
      }),
    );
  }
}
