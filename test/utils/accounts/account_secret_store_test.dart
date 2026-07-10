import 'dart:io';

import 'package:pili_plus/utils/accounts/account_secret_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('AccountSecretStore', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('account_secret_store_');
      AccountSecretStore.init(tempDir.path);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('does not persist account secrets as plaintext', () {
      AccountSecretStore.write(
        '12345',
        const AccountSecret(
          cookies: {'SESSDATA': 'session-token', 'bili_jct': 'csrf-token'},
          accessKey: 'access-token',
          refresh: 'refresh-token',
        ),
      );

      final raw = File(
        path.join(tempDir.path, AccountSecretStore.dataFileName),
      ).readAsStringSync();

      expect(raw, isNot(contains('session-token')));
      expect(raw, isNot(contains('csrf-token')));
      expect(raw, isNot(contains('access-token')));
      expect(raw, isNot(contains('refresh-token')));
    });

    test('loads persisted account secrets after reinitialization', () {
      AccountSecretStore.write(
        '12345',
        const AccountSecret(
          cookies: {'DedeUserID': '12345', 'bili_jct': 'csrf-token'},
          accessKey: 'access-token',
          refresh: 'refresh-token',
        ),
      );

      AccountSecretStore.init(tempDir.path);

      final secret = AccountSecretStore.read('12345');
      expect(secret?.cookies, {
        'DedeUserID': '12345',
        'bili_jct': 'csrf-token',
      });
      expect(secret?.accessKey, 'access-token');
      expect(secret?.refresh, 'refresh-token');
    });

    test('recovers the last known good encrypted generation', () {
      const first = AccountSecret(
        cookies: {'DedeUserID': '12345'},
        accessKey: 'first',
        refresh: null,
      );
      AccountSecretStore.write('12345', first);
      AccountSecretStore.write(
        '12345',
        const AccountSecret(
          cookies: {'DedeUserID': '12345'},
          accessKey: 'second',
          refresh: null,
        ),
      );
      File(
        path.join(tempDir.path, AccountSecretStore.dataFileName),
      ).writeAsStringSync('truncated', flush: true);

      AccountSecretStore.init(tempDir.path);

      expect(AccountSecretStore.read('12345')?.accessKey, 'first');
    });
  });
}
