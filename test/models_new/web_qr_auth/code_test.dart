import 'package:pili_plus/models_new/web_qr_auth/code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebQrLoginCode.parse', () {
    test('accepts official scan-web URL', () {
      final code = WebQrLoginCode.parse(
        'https://account.bilibili.com/h5/account-h5/auth/scan-web'
        '?navhide=1&callback=close&qrcode_key=0123456789abcdef0123456789abcdef&from=',
      );

      expect(code.key, '0123456789abcdef0123456789abcdef');
    });

    test('trims surrounding whitespace', () {
      final code = WebQrLoginCode.parse(
        '  https://account.bilibili.com/h5/account-h5/auth/scan-web'
        '?qrcode_key=0123456789abcdef0123456789abcdef  ',
      );

      expect(code.key, '0123456789abcdef0123456789abcdef');
    });

    for (final value in <String>[
      'http://account.bilibili.com/h5/account-h5/auth/scan-web'
          '?qrcode_key=0123456789abcdef0123456789abcdef',
      'https://account.bilibili.com.example.com/h5/account-h5/auth/scan-web'
          '?qrcode_key=0123456789abcdef0123456789abcdef',
      'https://user@account.bilibili.com/h5/account-h5/auth/scan-web'
          '?qrcode_key=0123456789abcdef0123456789abcdef',
      'https://account.bilibili.com:443/h5/account-h5/auth/scan-web'
          '?qrcode_key=0123456789abcdef0123456789abcdef',
      'https://account.bilibili.com:0443/h5/account-h5/auth/scan-web'
          '?qrcode_key=0123456789abcdef0123456789abcdef',
      'https://account.bilibili.com/h5/account-h5/auth/scan-web/'
          '?qrcode_key=0123456789abcdef0123456789abcdef',
      'https://account.bilibili.com/h5/account-h5/auth/scan-web'
          '?qrcode_key=0123456789abcdef0123456789abcdef#fragment',
      'https://account.bilibili.com/h5/account-h5/auth/scan-web',
      'https://account.bilibili.com/h5/account-h5/auth/scan-web?qrcode_key=',
      'https://account.bilibili.com/h5/account-h5/auth/scan-web'
          '?qrcode_key=0123456789abcdef0123456789abcdef'
          '&qrcode_key=fedcba9876543210fedcba9876543210',
      'https://account.bilibili.com/h5/account-h5/auth/scan-web?qrcode_key=short',
    ]) {
      test('rejects invalid URL: $value', () {
        expect(() => WebQrLoginCode.parse(value), throwsFormatException);
      });
    }
  });
}
