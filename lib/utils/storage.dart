import 'dart:convert';
import 'dart:typed_data';

import 'package:pili_plus/models/model_owner.dart';
import 'package:pili_plus/models/user/danmaku_rule_adapter.dart';
import 'package:pili_plus/models/user/info.dart';
import 'package:pili_plus/services/crash/crash_reporter.dart';
import 'package:pili_plus/utils/android/android_mmkv_box.dart';
import 'package:pili_plus/utils/android/android_mmkv_storage_codec.dart';
import 'package:pili_plus/utils/accounts.dart';
import 'package:pili_plus/utils/accounts/account_adapter.dart';
import 'package:pili_plus/utils/accounts/account_secret_store.dart';
import 'package:pili_plus/utils/accounts/account_type_adapter.dart';
import 'package:pili_plus/utils/accounts/cookie_jar_adapter.dart';
import 'package:pili_plus/utils/path_utils.dart';
import 'package:pili_plus/utils/set_int_adapter.dart';
import 'package:pili_plus/utils/setting_secret_store.dart';
import 'package:pili_plus/utils/settings_backup_validator.dart';
import 'package:pili_plus/utils/storage/favorite_reply_migration.dart';
import 'package:pili_plus/utils/storage/favorite_reply_store.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:pili_plus/utils/storage/reply_cache_store.dart';
import 'package:pili_plus/utils/storage/settings_import_transaction.dart';
import 'package:pili_plus/utils/storage/settings_store.dart';
import 'package:pili_plus/utils/storage/watch_progress_store.dart';
import 'package:pili_plus/utils/utils.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

abstract final class GStorage {
  static late final Box<UserInfoData> userInfo;
  static late final Box<dynamic> historyWord;
  static late final Box<dynamic> localCache;
  static late final Box<dynamic> setting;
  static late final Box<dynamic> video;
  static late final Box<int> watchProgress;
  static late final Box<Uint8List>? reply;
  static late final Box<Uint8List> favoriteReply;
  static late final SettingsStore settingsStore;
  static late final WatchProgressStore watchProgressStore;
  static late final ReplyCacheStore replyCacheStore;
  static late final FavoriteReplyStore favoriteReplyStore;

  static Future<void> init() async {
    Hive.init(path.join(appSupportDirPath, 'hive'));
    AccountSecretStore.init(path.join(appSupportDirPath, 'secrets'));
    SettingSecretStore.init(path.join(appSupportDirPath, 'secrets'));
    regAdapter();

    await Future.wait([
      // 登录用户信息
      openAndroidMmkvBackedBox<UserInfoData>(
        name: 'userInfo',
        valueEncoder: AndroidMmkvStorageCodec.encodeUserInfoData,
        valueDecoder: AndroidMmkvStorageCodec.decodeUserInfoData,
        openHive: () => Hive.openBox<UserInfoData>(
          'userInfo',
          compactionStrategy: (int entries, int deletedEntries) {
            return deletedEntries > 2;
          },
        ),
      ).then((res) => userInfo = res),
      // 本地缓存
      openAndroidMmkvBackedBox<dynamic>(
        name: 'localCache',
        valueEncoder: AndroidMmkvStorageCodec.encodeLocalCacheValue,
        valueDecoder: AndroidMmkvStorageCodec.decodeLocalCacheValue,
        openHive: () => Hive.openBox(
          'localCache',
          compactionStrategy: (int entries, int deletedEntries) {
            return deletedEntries > 4;
          },
        ),
      ).then((res) => localCache = res),
      // 设置
      openAndroidMmkvBackedBox<dynamic>(
        name: 'setting',
        openHive: () => Hive.openBox('setting'),
      ).then((res) => setting = res),
      // 搜索历史
      openAndroidMmkvBackedBox<dynamic>(
        name: 'historyWord',
        openHive: () => Hive.openBox(
          'historyWord',
          compactionStrategy: (int entries, int deletedEntries) {
            return deletedEntries > 10;
          },
        ),
      ).then((res) => historyWord = res),
      // 视频设置
      openAndroidMmkvBackedBox<dynamic>(
        name: 'video',
        openHive: () => Hive.openBox('video'),
      ).then((res) => video = res),
      Accounts.init(),
    ]);
    settingsStore = SettingsStore(setting, video);
    await migrateSettingSecrets();

    // Large progress box opens after critical prefs so first frame can use Pref sooner.
    watchProgress = await openAndroidMmkvBackedBox<int>(
      name: 'watchProgress',
      keyComparator: _intStrDescKeyComparator,
      loadMode: AndroidMmkvLoadMode.lazy,
      openHive: () => Hive.openBox<int>(
        'watchProgress',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 4;
        },
      ),
    );
    watchProgressStore = WatchProgressStore(
      watchProgress,
      orderStore: localCache,
    );
    await watchProgressStore.trim();

    favoriteReply = await _openReplyBox('favoriteReply');
    favoriteReplyStore = FavoriteReplyStore(
      favoriteReply,
      orderStore: localCache,
    );
    await favoriteReplyStore.trim();

    final shouldSaveReply =
        setting.get(SettingBoxKey.saveReply, defaultValue: true) as bool;
    final shouldMigrateFavorites =
        localCache.get(LocalCacheKey.favoriteReplyMigrationV1) != true;
    reply = await prepareLegacyReplyStorage(
      shouldSaveReply: shouldSaveReply,
      shouldMigrateFavorites: shouldMigrateFavorites,
      openLegacyBox: () => _openReplyBox('reply'),
      destination: favoriteReplyStore,
      markerStore: localCache,
      onError: (error, stackTrace, {required operation, required reason}) {
        CrashReporter.recordErrorSync(
          error,
          stackTrace,
          module: 'storage',
          operation: operation,
          reason: reason,
        );
      },
    );
    replyCacheStore = ReplyCacheStore(
      reply,
      orderStore: localCache,
    );
    await replyCacheStore.trim();
  }

  static String exportAllSettings() =>
      Utils.jsonEncoder.convert(_settingsBackup());

  static String exportAppData() {
    return Utils.jsonEncoder.convert({
      'schemaVersion': SettingsBackupValidator.currentSchemaVersion,
      'settings': _settingsBackup(),
      'accounts': Accounts.account.toMap(),
    });
  }

  static Map<String, dynamic> _settingsBackup() => {
    'schemaVersion': SettingsBackupValidator.currentSchemaVersion,
    setting.name: sanitizeSettingsForExport(setting.toMap()),
    video.name: video.toMap(),
  };

  static Future<void> importAppData(Map<String, dynamic> backup) async {
    SettingsBackupValidator.validateSchemaVersion(backup);
    final settings = backup['settings'];
    final accounts = backup['accounts'];
    if (settings is! Map || accounts is! Map) {
      throw const FormatException('Invalid application backup');
    }
    final settingsMap = Map<String, dynamic>.from(settings);
    final accountsMap = Map<dynamic, dynamic>.from(accounts);
    SettingsBackupValidator.validateBackup(
      settingsMap,
      currentSettings: setting.toMap(),
      currentVideo: video.toMap(),
    );
    Accounts.canonicalizeImportedAccounts(accountsMap);
    await importAllJsonSettings(settingsMap);
    await Accounts.importAccounts(accountsMap);
  }

  static Future<void> importAllSettings(String data) =>
      importAllJsonSettings(jsonDecode(data));

  static Future<void> importAllJsonSettings(Map<String, dynamic> map) async {
    SettingsBackupValidator.validateSchemaVersion(map);
    final settingData = SettingsBackupValidator.validateSection(
      map,
      setting.name,
      setting.toMap(),
    );
    final videoData = SettingsBackupValidator.validateSection(
      map,
      video.name,
      video.toMap(),
    );
    final importedWebDavPassword = settingData.remove(
      SettingBoxKey.webdavPassword,
    );
    final webDavPasswordSnapshot = SettingSecretStore.read(
      SettingBoxKey.webdavPassword,
    );

    await replaceSettingsSections(
      setting: SettingsImportTarget(
        read: setting.toMap,
        clear: () async {
          await setting.clear();
        },
        writeAll: setting.putAll,
      ),
      settingValues: settingData,
      video: SettingsImportTarget(
        read: video.toMap,
        clear: () async {
          await video.clear();
        },
        writeAll: video.putAll,
      ),
      videoValues: videoData,
      applySupplemental: importedWebDavPassword == null
          ? null
          : () => Future<void>.sync(
              () => SettingSecretStore.write(
                SettingBoxKey.webdavPassword,
                importedWebDavPassword.toString(),
              ),
            ),
      restoreSupplemental: () => Future<void>.sync(() {
        if (webDavPasswordSnapshot == null) {
          SettingSecretStore.delete(SettingBoxKey.webdavPassword);
          return;
        }
        SettingSecretStore.write(
          SettingBoxKey.webdavPassword,
          webDavPasswordSnapshot,
        );
      }),
      verifySupplemental: () {
        if (SettingSecretStore.read(SettingBoxKey.webdavPassword) !=
            webDavPasswordSnapshot) {
          throw StateError('Settings secret rollback verification failed');
        }
      },
    );
  }

  static Map<dynamic, dynamic> sanitizeSettingsForExport(
    Map<dynamic, dynamic> settings,
  ) => _jsonSafeMap(settings)..remove(SettingBoxKey.webdavPassword);

  /// Recursively converts non-string map keys to strings so the result always
  /// survives [Utils.jsonEncoder] (JSON only allows string keys). Guards the
  /// settings export against int-keyed values such as legacy per-UP skips.
  static Map<dynamic, dynamic> _jsonSafeMap(Map<dynamic, dynamic> map) {
    final result = <dynamic, dynamic>{};
    for (final entry in map.entries) {
      result[entry.key is String ? entry.key : '${entry.key}'] =
          _jsonSafeValue(entry.value);
    }
    return result;
  }

  static dynamic _jsonSafeValue(dynamic value) {
    if (value is Map) return _jsonSafeMap(value);
    if (value is List) return value.map(_jsonSafeValue).toList(growable: false);
    if (value is Set) return value.map(_jsonSafeValue).toList(growable: false);
    return value;
  }

  static Future<void> migrateSettingSecrets() async {
    final webDavPassword = setting.get(SettingBoxKey.webdavPassword);
    if (webDavPassword != null) {
      SettingSecretStore.write(
        SettingBoxKey.webdavPassword,
        webDavPassword.toString(),
      );
      await setting.delete(SettingBoxKey.webdavPassword);
    }
  }

  static void regAdapter() {
    Hive
      ..registerAdapter(OwnerAdapter())
      ..registerAdapter(UserInfoDataAdapter())
      ..registerAdapter(LevelInfoAdapter())
      ..registerAdapter(BiliCookieJarAdapter())
      ..registerAdapter(LoginAccountAdapter())
      ..registerAdapter(AccountTypeAdapter())
      ..registerAdapter(SetIntAdapter())
      ..registerAdapter(RuleFilterAdapter());
  }

  static Future<List<void>> compact() {
    return Future.wait([
      userInfo.compact(),
      historyWord.compact(),
      localCache.compact(),
      setting.compact(),
      video.compact(),
      Accounts.account.compact(),
      watchProgress.compact(),
      ?reply?.compact(),
      favoriteReply.compact(),
    ]);
  }

  static Future<List<void>> close() {
    return Future.wait([
      userInfo.close(),
      historyWord.close(),
      localCache.close(),
      setting.close(),
      video.close(),
      Accounts.account.close(),
      watchProgress.close(),
      ?reply?.close(),
      favoriteReply.close(),
    ]);
  }

  static Future<void> clear() async {
    // Clear the bounded stores before their shared order metadata box. Running
    // these clears beside localCache.clear() can recreate stale LRU keys after
    // the cache box has already been emptied.
    await Future.wait([
      replyCacheStore.clear(),
      favoriteReplyStore.clear(),
    ]);
    await Future.wait([
      userInfo.clear(),
      historyWord.clear(),
      setting.clear(),
      video.clear(),
      Accounts.clear(),
      Future<void>.sync(SettingSecretStore.clear),
      watchProgress.clear(),
    ]);
    await localCache.clear();
    // A full clear must not resurrect a closed legacy reply box on restart.
    await localCache.put(LocalCacheKey.favoriteReplyMigrationV1, true);
  }

  static Future<Box<Uint8List>> _openReplyBox(String name) {
    return openAndroidMmkvBackedBox<Uint8List>(
      name: name,
      keyComparator: _intStrDescKeyComparator,
      loadMode: AndroidMmkvLoadMode.lazy,
      openHive: () => Hive.openBox<Uint8List>(
        name,
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 10;
        },
      ),
    );
  }

  static int _intStrDescKeyComparator(dynamic k1, dynamic k2) {
    if (k1 is int) {
      if (k2 is int) {
        return k2.compareTo(k1);
      } else {
        return -1;
      }
    } else if (k2 is String) {
      final lenCompare = k2.length.compareTo((k1 as String).length);
      if (lenCompare == 0) {
        return k2.compareTo(k1);
      } else {
        return lenCompare;
      }
    } else {
      return 1;
    }
  }
}
