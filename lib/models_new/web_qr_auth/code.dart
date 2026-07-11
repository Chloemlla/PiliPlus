final class WebQrLoginCode {
  const WebQrLoginCode._(this.key);

  static const host = 'account.bilibili.com';
  static const path = '/h5/account-h5/auth/scan-web';

  final String key;

  static WebQrLoginCode parse(String value) {
    final input = value.trim();
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !_hasExactAuthority(input) ||
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

  static bool _hasExactAuthority(String value) {
    final schemeEnd = value.indexOf('://');
    if (schemeEnd == -1) {
      return false;
    }

    final authorityStart = schemeEnd + 3;
    final authorityEnd = value.indexOf('/', authorityStart);
    return authorityEnd != -1 &&
        value.substring(authorityStart, authorityEnd).toLowerCase() == host;
  }

  static final _keyPattern = RegExp(r'^[A-Za-z0-9_-]{16,256}$');
}
