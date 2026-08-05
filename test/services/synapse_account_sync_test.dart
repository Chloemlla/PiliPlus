import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/services/synapse_account_sync.dart';

void main() {
  group('synapseCookieHash', () {
    test('is deterministic for the same cookie', () {
      const cookie = 'SESSDATA=a; bili_jct=b; DedeUserID=123';
      expect(synapseCookieHash(cookie), synapseCookieHash(cookie));
    });

    test('differs when the cookie changes', () {
      expect(
        synapseCookieHash('SESSDATA=a; bili_jct=b'),
        isNot(synapseCookieHash('SESSDATA=b; bili_jct=b')),
      );
    });
  });

  group('decodeSyncedAccounts / encodeSyncedAccounts', () {
    test('round-trips a persisted snapshot', () {
      const state = SynapseSyncedAccountState(cookieHash: 'abc', at: '2026-01-01');
      final encoded = encodeSyncedAccounts({'12345': state});
      final decoded = decodeSyncedAccounts(encoded);
      expect(decoded, {'12345': state});
    });

    test('returns an empty map for null, empty or malformed input', () {
      expect(decodeSyncedAccounts(null), isEmpty);
      expect(decodeSyncedAccounts(''), isEmpty);
      expect(decodeSyncedAccounts('not-json'), isEmpty);
      expect(decodeSyncedAccounts('[1,2,3]'), isEmpty);
    });

    test('skips entries without a cookie hash', () {
      final decoded = decodeSyncedAccounts(
        '{"1":{"at":"x"},"2":{"cookieHash":"abc","at":"y"}}',
      );
      expect(decoded, {
        '2': const SynapseSyncedAccountState(cookieHash: 'abc', at: 'y'),
      });
    });
  });

  group('findChangedAccountUids', () {
    test('reports a brand-new uid as changed', () {
      final changed = findChangedAccountUids(
        const {},
        {'12345': 'SESSDATA=a'},
      );
      expect(changed, ['12345']);
    });

    test('skips a uid whose cookie matches the last synced hash', () {
      final previous = {
        '12345': SynapseSyncedAccountState(
          cookieHash: synapseCookieHash('SESSDATA=a'),
          at: '2026-01-01',
        ),
      };
      final changed = findChangedAccountUids(previous, {'12345': 'SESSDATA=a'});
      expect(changed, isEmpty);
    });

    test('reports a uid whose cookie changed since the last sync', () {
      final previous = {
        '12345': SynapseSyncedAccountState(
          cookieHash: synapseCookieHash('SESSDATA=old'),
          at: '2026-01-01',
        ),
      };
      final changed = findChangedAccountUids(previous, {'12345': 'SESSDATA=new'});
      expect(changed, ['12345']);
    });

    test('returns changed uids in input order', () {
      final previous = {
        '111': SynapseSyncedAccountState(
          cookieHash: synapseCookieHash('a'),
          at: '',
        ),
      };
      final changed = findChangedAccountUids(
        previous,
        {'222': 'b', '111': 'a', '333': 'c'},
      );
      expect(changed, ['222', '333']);
    });
  });
}
