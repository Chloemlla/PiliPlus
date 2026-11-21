import 'package:cookie_jar/cookie_jar.dart'
    show Cookie, DefaultCookieJar, SerializableCookie;
import 'package:dio/dio.dart' show Options;
import 'package:pili_plus/http/init.dart';
import 'package:pili_plus/utils/accounts/account.dart';

/// Fetches the anonymous device fingerprints (b_3/b_4) from Bilibili.
///
/// Kept next to - but outside of - `account.dart` so that `utils/accounts/`
/// never imports `http/`: storage initialization must not transitively depend
/// on `storage_pref.dart` (enforced by `tool/check_import_boundaries.py`).
Future<void> refreshAnonymousBuvidCookies(DefaultCookieJar cookieJar) async {
  try {
    final res = await Request().get(
      '/x/frontend/finger/spi',
      options: Options(extra: {'account': const NoAccount()}),
    );
    final resData = res.data;
    if (resData['code'] == 0) {
      final data = resData['data'];
      final String b3 = data['b_3'];
      final String b4 = data['b_4'];
      final bnut = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      (cookieJar.domainCookies['bilibili.com'] ??= {
          '/': {},
        })['/']!
        ..['buvid3'] = SerializableCookie(
          Cookie('buvid3', b3)..setBiliDomain(),
        )
        ..['b_nut'] = SerializableCookie(
          Cookie('b_nut', bnut)..setBiliDomain(),
        )
        ..['buvid4'] = SerializableCookie(
          Cookie('buvid4', b4)..setBiliDomain(),
        );
    } else {
      throw resData;
    }
  } catch (_) {
    cookieJar.setBuvid3();
  }
}
