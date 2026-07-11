final class WebQrLoginCode {
  const WebQrLoginCode._(this.key);

  static const host = 'account.bilibili.com';
  static const path = '/h5/account-h5/auth/scan-web';

  final String key;

  static WebQrLoginCode parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != host ||
        uri.path != path ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.fragment.isNotEmpty) {
      throw const FormatException('不是有效的哔哩哔哩网页登录二维码');
    }

    final keys = uri.queryParametersAll['qrcode_key'];
    if (keys == null || keys.length != 1) {
      throw const FormatException('二维码缺少有效的登录标识');
    }

    final key = keys.single;
    if (!_keyPattern.hasMatch(key)) {
      throw const FormatException('二维码登录标识格式无效');
    }

    return WebQrLoginCode._(key);
  }

  static final _keyPattern = RegExp(r'^[A-Za-z0-9_-]{16,256}$');
}
