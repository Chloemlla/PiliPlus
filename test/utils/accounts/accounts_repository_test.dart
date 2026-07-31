import 'dart:io';

import 'package:pili_plus/models/common/account_type.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/accounts/account_adapter.dart';
import 'package:pili_plus/utils/accounts/account_secret_store.dart';
import 'package:pili_plus/utils/accounts/account_type_adapter.dart';
import 'package:pili_plus/utils/accounts/cookie_jar_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDirectory;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'pili_accounts_repository_test_',
    );
    Hive.init(tempDirectory.path);
    AccountSecretStore.init(tempDirectory.path);
    Hive
      ..registerAdapter(BiliCookieJarAdapter())
      ..registerAdapter(LoginAccountAdapter())
      ..registerAdapter(AccountTypeAdapter());
  });

  setUp(() async {
    Accounts.configureSessionHandlers(
      activateAccount: (_) async {},
      onMainLogin: () async {},
      onMainLogout: () async {},
    );
    await Accounts.init();
    await Accounts.account.clear();
    AccountSecretStore.clear();
  });

  tearDown(() async {
    await Accounts.account.close();
    await Hive.deleteBoxFromDisk('account');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'refresh persists canonical keys before aliases are removed or deleted',
    () async {
      final firstAlias = _account(
        mid: '111',
        accessKey: 'first-token',
        types: {AccountType.heartbeat},
      );
      final secondAlias = _account(
        mid: '111',
        accessKey: 'second-token',
        types: {AccountType.video},
      );
      final conflictingCanonical = _account(
        mid: '222',
        accessKey: 'canonical-token',
        types: {AccountType.main},
      );
      for (final account in [firstAlias, secondAlias, conflictingCanonical]) {
        account.persistSecret();
      }
      await Accounts.account.putAll({
        '222': firstAlias,
        'a-alias': secondAlias,
        'z-alias': conflictingCanonical,
      });

      await Accounts.refresh();

      expect(Accounts.account.keys, unorderedEquals(<String>['111', '222']));
      expect(Accounts.account.get('222')?.secretKey, '222');
      expect(
        Accounts.account.get('111')?.type,
        containsAll(<AccountType>[AccountType.heartbeat, AccountType.video]),
      );

      final canonical = Accounts.account.get('111')!;
      await Accounts.deleteAll({canonical});
      await Accounts.refresh();

      expect(Accounts.account.keys, unorderedEquals(<String>['222']));
      expect(AccountSecretStore.read('111'), isNull);
    },
  );
}

LoginAccount _account({
  required String mid,
  required String accessKey,
  required Set<AccountType> types,
}) => LoginAccount(
  BiliCookieJar.fromJson({
    'DedeUserID': mid,
    'bili_jct': 'csrf-$mid',
  }),
  accessKey,
  null,
  types,
);
