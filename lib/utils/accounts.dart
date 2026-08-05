import 'package:pili_plus/models/common/account_type.dart';
import 'package:pili_plus/utils/accounts/account.dart';
import 'package:pili_plus/utils/accounts/account_secret_store.dart';
import 'package:hive_ce/hive.dart';

typedef AccountActivator = Future<void> Function(Account account);
typedef AccountSessionCallback = Future<void> Function();

abstract final class Accounts {
  static void Function(bool isLogin)? onHeartbeatLoginChanged;
  static AccountActivator? _activateAccount;
  static AccountSessionCallback? _onMainLogin;
  static AccountSessionCallback? _onMainLogout;
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

  static void configureSessionHandlers({
    required AccountActivator activateAccount,
    required AccountSessionCallback onMainLogin,
    required AccountSessionCallback onMainLogout,
  }) {
    _activateAccount = activateAccount;
    _onMainLogin = onMainLogin;
    _onMainLogout = onMainLogout;
  }

  static Future<void> refresh() async {
    final obsoleteKeys = <dynamic>[];
    final candidates = <_AccountCandidate>[];
    for (final entry in account.toMap().entries) {
      final a = entry.value;
      if (!a.shouldKeep) {
        obsoleteKeys.add(entry.key);
        continue;
      }
      candidates.add(_AccountCandidate(entry.key, a));
      if (entry.key != a.secretKey) obsoleteKeys.add(entry.key);
    }
    final validAccounts = _canonicalizeCandidates(candidates);
    final nextAccountMode = List<Account>.filled(
      AccountType.values.length,
      AnonymousAccount(),
    );
    final canonicalKeys = validAccounts.keys.toList()..sort();
    for (final key in canonicalKeys) {
      final a = validAccounts[key]!;
      for (final t in a.type) {
        nextAccountMode[t.index] = a;
      }
    }

    if (validAccounts.isNotEmpty) {
      await account.putAll(validAccounts);
    }
    // An alias source key may now be canonical for another selected account.
    final safeObsoleteKeys = obsoleteKeys
        .where((key) => !validAccounts.containsKey(key))
        .toList();
    if (safeObsoleteKeys.isNotEmpty) {
      await account.deleteAll(safeObsoleteKeys);
    }
    for (int i = 0; i < nextAccountMode.length; i++) {
      accountMode[i] = nextAccountMode[i];
    }
    onHeartbeatLoginChanged?.call(accountMode[AccountType.heartbeat.index].isLogin);

    final activateAccount = _activateAccount;
    if (activateAccount != null) {
      await Future.wait(
        (accountMode.toSet()..removeWhere((i) => i.activated)).map(
          activateAccount,
        ),
      );
    }
  }

  static Map<String, LoginAccount> canonicalizeImportedAccounts(
    Map<dynamic, dynamic> json,
  ) {
    final candidates = <_AccountCandidate>[];
    for (final entry in json.entries) {
      if (entry.value is! Map) {
        throw FormatException('Invalid imported account: ${entry.key}');
      }
      late final LoginAccount imported;
      try {
        imported = LoginAccount.fromJson(entry.value as Map);
      } catch (error) {
        throw FormatException(
          'Invalid imported account ${entry.key}: $error',
        );
      }
      if (!imported.shouldKeep) {
        throw FormatException(
          'Imported account ${entry.key} is missing credentials',
        );
      }
      candidates.add(_AccountCandidate(entry.key, imported));
    }
    return _canonicalizeCandidates(candidates);
  }

  static Future<void> importAccounts(Map<dynamic, dynamic> json) async {
    final canonical = canonicalizeImportedAccounts(json);
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
    final activateAccount = _activateAccount;
    if (activateAccount != null) {
      await activateAccount(AnonymousAccount());
    }
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
      final onMainLogout = _onMainLogout;
      if (onMainLogout != null) await onMainLogout();
    }
  }

  static Future<void> set(AccountType key, Account account) async {
    final oldAccount = accountMode[key.index]..type.remove(key);
    accountMode[key.index] = account..type.add(key);
    await Future.wait([?account.onChange(), ?oldAccount.onChange()]);
    final activateAccount = _activateAccount;
    if (!account.activated && activateAccount != null) {
      await activateAccount(account);
    }
    switch (key) {
      case AccountType.main:
        final callback = account.isLogin ? _onMainLogin : _onMainLogout;
        if (callback != null) await callback();
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

final class _AccountCandidate {
  _AccountCandidate(this.sourceKey, this.account);

  final dynamic sourceKey;
  final LoginAccount account;

  bool get isCanonical => sourceKey == account.secretKey;

  String get orderKey => '${sourceKey.runtimeType}:$sourceKey';
}

Map<String, LoginAccount> _canonicalizeCandidates(
  Iterable<_AccountCandidate> candidates,
) {
  final sorted = candidates.toList()
    ..sort((a, b) {
      final secretKeyCompare = a.account.secretKey.compareTo(
        b.account.secretKey,
      );
      if (secretKeyCompare != 0) return secretKeyCompare;
      final canonicalCompare = (a.isCanonical ? 0 : 1).compareTo(
        b.isCanonical ? 0 : 1,
      );
      if (canonicalCompare != 0) return canonicalCompare;
      return a.orderKey.compareTo(b.orderKey);
    });
  final canonical = <String, LoginAccount>{};
  for (final candidate in sorted) {
    final key = candidate.account.secretKey;
    final selected = canonical[key];
    if (selected == null) {
      canonical[key] = candidate.account;
    } else {
      selected.type.addAll(candidate.account.type);
    }
  }
  return canonical;
}
