import 'package:pili_plus/utils/accounts/account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoginAccount cookie validation', () {
    test('accepts accounts with required cookies', () {
      final account = LoginAccount(
        BiliCookieJar.fromJson({
          'DedeUserID': '12345',
          'bili_jct': 'csrf-token',
        }),
        null,
        null,
      );

      expect(account.shouldKeep, isTrue);
      expect(account.isLogin, isTrue);
      expect(account.mid, 12345);
      expect(account.csrf, 'csrf-token');
    });

    test('does not throw for missing required cookies', () {
      final account = LoginAccount(
        BiliCookieJar.fromJson({'SESSDATA': 'session'}),
        null,
        null,
      );

      expect(account.shouldKeep, isFalse);
      expect(account.isLogin, isFalse);
      expect(account.mid, 0);
      expect(account.csrf, isEmpty);
    });

    test('skips malformed cookie list entries', () {
      final account = LoginAccount(
        BiliCookieJar.fromList([
          {'name': 'DedeUserID', 'value': '12345'},
          {'name': 'bili_jct', 'value': 'csrf-token'},
          {'name': 'missing-value'},
          {'value': 'missing-name'},
          'not-a-cookie',
        ]),
        null,
        null,
      );

      expect(account.shouldKeep, isTrue);
      expect(account.mid, 12345);
      expect(account.csrf, 'csrf-token');
    });
  });
}
