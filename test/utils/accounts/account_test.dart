import 'package:pili_plus/models/common/account_type.dart';
import 'package:pili_plus/utils/accounts.dart';
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

  group('account import canonicalization', () {
    test('prefers the canonical source key and merges assigned modes', () {
      final canonical = Accounts.canonicalizeImportedAccounts({
        'z-alias': _accountJson(
          accessKey: 'alias-token',
          type: AccountType.heartbeat,
        ),
        '12345': _accountJson(
          accessKey: 'canonical-token',
          type: AccountType.main,
        ),
      });

      expect(canonical.keys, ['12345']);
      expect(canonical['12345']?.accessKey, 'canonical-token');
      expect(
        canonical['12345']?.type,
        containsAll(<AccountType>[AccountType.main, AccountType.heartbeat]),
      );
    });

    test('resolves alias-only duplicates independently of input order', () {
      final first = Accounts.canonicalizeImportedAccounts({
        'z-alias': _accountJson(accessKey: 'z-token'),
        'a-alias': _accountJson(accessKey: 'a-token'),
      });
      final reversed = Accounts.canonicalizeImportedAccounts({
        'a-alias': _accountJson(accessKey: 'a-token'),
        'z-alias': _accountJson(accessKey: 'z-token'),
      });

      expect(first.keys, ['12345']);
      expect(first['12345']?.accessKey, 'a-token');
      expect(reversed['12345']?.accessKey, 'a-token');
    });

    test('rejects malformed imported records', () {
      expect(
        () => Accounts.canonicalizeImportedAccounts({'alias': true}),
        throwsFormatException,
      );
    });
  });
}

Map<String, Object?> _accountJson({
  required String accessKey,
  AccountType? type,
}) => {
  'cookies': const {
    'DedeUserID': '12345',
    'bili_jct': 'csrf-token',
  },
  'accessKey': accessKey,
  'refresh': null,
  'type': [if (type != null) type.index],
};
