import 'package:pili_plus/http/init.dart';
import 'package:pili_plus/models/common/account_type.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/accounts/account_secret_store.dart';
import 'package:pili_plus/utils/login_utils.dart';
import 'package:hive_ce/hive.dart';

abstract final class Accounts {
  static void Function(bool isLogin)? onHeartbeatLoginChanged;
  static late final Box<LoginAccount> account;
  static final List<Account> accountMode = List.filled(
    AccountType.values.length,
    AnonymousAccount(),
  );
  static bool get mainEqVideo => main == video;
  static Account get main => accountMode[AccountType.main.index];
  static Account get video => accountMode[AccountType.video.index];
  static Account get heartbeat => accountMode[AccountType.heartbeat.index];
  static Account get history {
    final heartbeat = Accounts.heartbeat;
    if (heartbeat is AnonymousAccount) {
      return Accounts.main;
    }
    return heartbeat;
  }
  // static set main(Account account) => set(AccountType.main, account);

  static Future<void> init() async {
    account = await Hive.openBox(
      'account',
      compactionStrategy: (int entries, int deletedEntries) {
        return deletedEntries > 2;
      },
    );
  }

  static Future<void> refresh() async {
    for (int i = 0; i < AccountType.values.length; i++) {
      accountMode[i] = AnonymousAccount();
    }
    final obsoleteKeys = <dynamic>[];
    final validAccounts = <String, LoginAccount>{};
    for (final entry in account.toMap().entries) {
      final a = entry.value;
      if (!a.shouldKeep) {
        obsoleteKeys.add(entry.key);
        continue;
      }
      validAccounts[a.secretKey] = a;
      if (entry.key != a.secretKey) obsoleteKeys.add(entry.key);
      for (final t in a.type) {
        accountMode[t.index] = a;
      }
    }
    if (validAccounts.isNotEmpty) {
      await account.putAll(validAccounts);
    }
    if (obsoleteKeys.isNotEmpty) {
      await account.deleteAll(obsoleteKeys);
    }
    await Future.wait(
      (accountMode.toSet()..removeWhere((i) => i.activated)).map(
        Request.buvidActive,
      ),
    );
  }

  static Future<void> importAccounts(Map<dynamic, dynamic> json) async {
    final canonical = <String, LoginAccount>{};
    for (final value in json.values) {
      final imported = LoginAccount.fromJson(value);
      if (!imported.shouldKeep) {
        throw const FormatException('Imported account is missing credentials');
      }
      final key = imported.secretKey;
      if (canonical.containsKey(key)) {
        throw FormatException('Duplicate imported account: $key');
      }
      canonical[key] = imported;
    }
    for (final imported in canonical.values) {
      imported.persistSecret();
    }
    await account.putAll(canonical);
    await refresh();
  }

  static Future<void> clear() async {
    await account.clear();
    AccountSecretStore.clear();
    for (int i = 0; i < AccountType.values.length; i++) {
      accountMode[i] = AnonymousAccount();
    }
    await AnonymousAccount().delete();
    Request.buvidActive(AnonymousAccount());
  }

  static Future<void> deleteAll(Set<Account> accounts) async {
    final isLoginMain = Accounts.main.isLogin;
    for (int i = 0; i < AccountType.values.length; i++) {
      if (accounts.contains(accountMode[i])) {
        accountMode[i] = AnonymousAccount();
      }
    }
    await Future.wait(accounts.map((i) => i.delete()));
    if (isLoginMain && !Accounts.main.isLogin) {
      await LoginUtils.onLogoutMain();
    }
  }

  static Future<void> set(AccountType key, Account account) async {
    final oldAccount = accountMode[key.index]..type.remove(key);
    accountMode[key.index] = account..type.add(key);
    await Future.wait([?account.onChange(), ?oldAccount.onChange()]);
    if (!account.activated) await Request.buvidActive(account);
    switch (key) {
      case AccountType.main:
        await (account.isLogin
            ? LoginUtils.onLoginMain()
            : LoginUtils.onLogoutMain());
        break;
      case AccountType.heartbeat:
        onHeartbeatLoginChanged?.call(account.isLogin);
        break;
      default:
        break;
    }
  }

  @pragma("vm:prefer-inline")
  static Account get(AccountType key) {
    return accountMode[key.index];
  }
}
