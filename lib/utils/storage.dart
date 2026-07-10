import 'dart:convert';
import 'dart:typed_data';

import 'package:pili_plus/models/model_owner.dart';
import 'package:pili_plus/models/user/danmaku_rule_adapter.dart';
import 'package:pili_plus/models/user/info.dart';
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
import 'package:pili_plus/utils/storage_key.dart';
import 'package:pili_plus/utils/storage_pref.dart';
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
      openAndroidMmkvBackedBox<int>(
        name: 'watchProgress',
        keyComparator: _intStrDescKeyComparator,
        openHive: () => Hive.openBox<int>(
          'watchProgress',
          keyComparator: _intStrDescKeyComparator,
          compactionStrategy: (entries, deletedEntries) {
            return deletedEntries > 4;
          },
        ),
      ).then((res) => watchProgress = res),
    ]);
    await migrateSettingSecrets();

    if (Pref.saveReply) {
      reply = await openAndroidMmkvBackedBox<Uint8List>(
        name: 'reply',
        keyComparator: _intStrDescKeyComparator,
        openHive: () => Hive.openBox<Uint8List>(
          'reply',
          keyComparator: _intStrDescKeyComparator,
          compactionStrategy: (entries, deletedEntries) {
            return deletedEntries > 10;
          },
        ),
      );
    } else {
      reply = null;
    }
  }

  static String exportAllSettings() {
    return Utils.jsonEncoder.convert({
      'schemaVersion': SettingsBackupValidator.currentSchemaVersion,
      setting.name: sanitizeSettingsForExport(setting.toMap()),
      video.name: video.toMap(),
    });
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
    final settingSnapshot = setting.toMap();
    final videoSnapshot = video.toMap();
    final webDavPasswordSnapshot = SettingSecretStore.read(
      SettingBoxKey.webdavPassword,
    );

    try {
      await setting.clear();
      await setting.putAll(settingData);
      await video.clear();
      await video.putAll(videoData);
      if (importedWebDavPassword != null) {
        SettingSecretStore.write(
          SettingBoxKey.webdavPassword,
          importedWebDavPassword.toString(),
        );
      }
    } catch (_) {
      await setting.clear();
      await setting.putAll(settingSnapshot);
      await video.clear();
      await video.putAll(videoSnapshot);
      if (webDavPasswordSnapshot == null) {
        SettingSecretStore.delete(SettingBoxKey.webdavPassword);
      } else {
        SettingSecretStore.write(
          SettingBoxKey.webdavPassword,
          webDavPasswordSnapshot,
        );
      }
      rethrow;
    }
  }

  static Map<dynamic, dynamic> sanitizeSettingsForExport(
    Map<dynamic, dynamic> settings,
  ) => Map<dynamic, dynamic>.of(settings)..remove(SettingBoxKey.webdavPassword);

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
    ]);
  }

  static Future<List<void>> clear() {
    return Future.wait([
      userInfo.clear(),
      historyWord.clear(),
      localCache.clear(),
      setting.clear(),
      video.clear(),
      Accounts.clear(),
      Future<void>.sync(SettingSecretStore.clear),
      watchProgress.clear(),
      ?reply?.clear(),
    ]);
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
