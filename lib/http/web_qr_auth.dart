import 'package:pili_plus/common/constants.dart';
import 'package:pili_plus/http/init.dart';
import 'package:pili_plus/http/retry_interceptor.dart';
import 'package:pili_plus/models_new/web_qr_auth/scene.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/app_sign.dart';
import 'package:pili_plus/utils/login_utils.dart';
import 'package:dio/dio.dart';

abstract final class WebQrAuthHttp {
  static const _baseUrl = 'https://passport.bilibili.com';
  static const _referer =
      'https://account.bilibili.com/h5/account-h5/auth/scan-web';
  static final _deviceId = LoginUtils.genDeviceId();

  static Future<void> check(Account account, String qrcodeKey) async {
    final params = _signedParams(account, {'qrcode_key': qrcodeKey});
    final response = await Request().get(
      '$_baseUrl/x/passport-login/web/qrcode/check',
      queryParameters: params,
      options: _options(account),
    );
    _requireSuccess(response.data);
  }

  static Future<WebQrAuthScene> scene(
    Account account,
    String qrcodeKey,
  ) async {
    final params = _signedParams(account, {'qrcode_key': qrcodeKey});
    final response = await Request().get(
      '$_baseUrl/x/passport-login/web/qrcode/scene',
      queryParameters: params,
      options: _options(account),
    );
    final json = _requireSuccess(response.data);
    return WebQrAuthScene.fromJson(json['data']);
  }

  static Future<void> confirm({
    required Account account,
    required String qrcodeKey,
    required bool transient,
    String? environmentKey,
    String? verifyKey,
    String? verifyCode,
  }) async {
    final data = _signedParams(account, {
      'qrcode_key': qrcodeKey,
      'transient': transient ? 'true' : 'false',
      'env_key': environmentKey ?? '',
      'verify_type': verifyKey == null ? '' : 'verify_tel',
      'verify_key': verifyKey ?? '',
      'verify_code': verifyCode ?? '',
    });
    final response = await Request().post(
      '$_baseUrl/x/passport-login/web/qrcode/confirm',
      data: data,
      options: _options(account),
    );
    _requireSuccess(response.data);
  }

  static Future<String?> getMaskedPhone(Account account) async {
    final response = await Request().get(
      '$_baseUrl/x/safecenter/user/info',
      queryParameters: _signedParams(account),
      options: _options(account),
    );
    final json = _requireSuccess(response.data);
    final data = _stringMap(json['data']);
    final accountInfo = _stringMap(data['account_info']);
    return _stringOrNull(accountInfo['hide_tel']);
  }

  static Future<WebQrCaptcha> prepareCaptcha(Account account) async {
    final response = await Request().post(
      '$_baseUrl/x/safecenter/captcha/pre',
      data: _signedParams(account),
      options: _options(account),
    );
    final json = _requireSuccess(response.data);
    final data = _stringMap(json['data']);
    return WebQrCaptcha(
      gt: _requiredString(data, 'gee_gt'),
      challenge: _requiredString(data, 'gee_challenge'),
      recaptchaToken: _requiredString(data, 'recaptcha_token'),
    );
  }

  static Future<String> sendSms({
    required Account account,
    required WebQrCaptcha captcha,
    required String geetestChallenge,
    required String geetestValidate,
    required String geetestSeccode,
  }) async {
    final response = await Request().post(
      '$_baseUrl/x/safecenter/common/sms/send',
      data: _signedParams(account, {
        'sms_type': 'loginTelCheck',
        'recaptcha_token': captcha.recaptchaToken,
        'gee_challenge': geetestChallenge,
        'gee_validate': geetestValidate,
        'gee_seccode': geetestSeccode,
        'img_code': '',
      }),
      options: _options(account),
    );
    final json = _requireSuccess(response.data);
    final data = _stringMap(json['data']);
    return _requiredString(data, 'captcha_key');
  }

  static Future<void> verifySms({
    required Account account,
    required String captchaKey,
    required String code,
  }) async {
    final response = await Request().get(
      '$_baseUrl/x/safecenter/common/sms/check',
      queryParameters: _signedParams(account, {
        'sms_type': 'loginTelCheck',
        'captcha_key': captchaKey,
        'code': code,
      }),
      options: _options(account),
    );
    _requireSuccess(response.data);
  }

  static Map<String, String> _signedParams(
    Account account, [
    Map<String, String> values = const {},
  ]) {
    final params = <String, String>{
      'actionKey': 'appkey',
      'build': '2001100',
      'buvid': LoginUtils.buvid,
      'c_locale': 'zh_CN',
      'channel': 'master',
      'device': 'pad',
      'device_id': _deviceId,
      'device_name': 'android',
      'device_platform': 'android',
      'local_id': LoginUtils.buvid,
      'mobi_app': 'android_hd',
      'platform': 'android',
      's_locale': 'zh_CN',
      'statistics': Constants.statistics,
      if (account.csrf.isNotEmpty) 'csrf': account.csrf,
      if (account.accessKey case final accessKey? when accessKey.isNotEmpty)
        'access_key': accessKey,
      ...values,
    };
    AppSign.appSign(params);
    return params;
  }

  static Options _options(Account account) => Options(
    contentType: Headers.formUrlEncodedContentType,
    headers: {
      ...Constants.baseHeaders,
      'app-key': 'android_hd',
      'buvid': LoginUtils.buvid,
      'env': 'prod',
      'referer': _referer,
      'user-agent': Constants.userAgent,
      'x-bili-trace-id': Constants.traceId,
    },
    extra: {
      'account': account,
      RetryInterceptor.disableRetryKey: true,
    },
  );

  static Map<String, Object?> _requireSuccess(Object? responseData) {
    final json = _stringMap(responseData);
    final code = switch (json['code']) {
      final int value => value,
      final num value => value.toInt(),
      _ => -1,
    };
    final message = _stringOrNull(json['message']) ?? '授权请求失败';
    if (code != 0) {
      throw WebQrAuthException(code, message);
    }
    return json;
  }

  static Map<String, Object?> _stringMap(Object? value) {
    if (value case final Map map) {
      return {
        for (final entry in map.entries)
          if (entry.key case final String key) key: entry.value,
      };
    }
    throw const WebQrAuthException(-1, '授权接口返回格式异常');
  }

  static String _requiredString(Map<String, Object?> map, String key) {
    final value = _stringOrNull(map[key]);
    if (value == null) {
      throw const WebQrAuthException(-1, '安全验证数据不完整');
    }
    return value;
  }

  static String? _stringOrNull(Object? value) {
    if (value case final String text when text.trim().isNotEmpty) {
      return text.trim();
    }
    return null;
  }
}

final class WebQrCaptcha {
  const WebQrCaptcha({
    required this.gt,
    required this.challenge,
    required this.recaptchaToken,
  });

  final String gt;
  final String challenge;
  final String recaptchaToken;
}

final class WebQrAuthException implements Exception {
  const WebQrAuthException(this.code, this.message);

  final int code;
  final String message;

  bool get isExpired => code == 86038;

  @override
  String toString() => message;
}
