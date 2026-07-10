import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pili_plus/models/user/danmaku_rule.dart';
import 'package:pili_plus/models/user/info.dart';
import 'package:pili_plus/utils/android/android_mmkv_box.dart';
import 'package:pili_plus/utils/android/android_mmkv_storage_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory hiveDirectory;
  late List<String> hiveBoxNames;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pili_mmkv_test_');
    Hive.init(hiveDirectory.path);
  });

  setUp(() => hiveBoxNames = []);

  tearDown(() async {
    for (final name in hiveBoxNames) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box<dynamic>(name).close();
      }
      await Hive.deleteBoxFromDisk(name);
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('first Android open migrates Hive and records the marker', () async {
    final store = _MemoryAndroidMmkvStore();
    final name = _newHiveBoxName(hiveBoxNames, 'first_open');
    final hive = await Hive.openBox<dynamic>(name);
    await hive.putAll(const {
      'theme': 'dark',
      'ids': <int>{1, 2, 3},
    });

    final box = await openAndroidMmkvBackedBox<dynamic>(
      name: name,
      isAndroid: true,
      store: store,
      openHive: () => Future.value(hive),
    );

    expect(box, isA<AndroidMmkvBackedBox<dynamic>>());
    expect(box.get('theme'), 'dark');
    expect(box.get('ids'), <int>{1, 2, 3});
    expect(
      store.getRaw(
        AndroidMmkvStore.metaBox,
        AndroidMmkvStore.migrationKey(name),
      ),
      '1',
    );
    expect(hive.isOpen, isFalse);
    await box.close();
  });

  test('subsequent Android open reads MMKV without opening Hive', () async {
    final store = _MemoryAndroidMmkvStore();
    final name = _newHiveBoxName(hiveBoxNames, 'subsequent_open');
    final hive = await Hive.openBox<dynamic>(name);
    await hive.put('value', 42);
    final first = await openAndroidMmkvBackedBox<dynamic>(
      name: name,
      isAndroid: true,
      store: store,
      openHive: () => Future.value(hive),
    );
    await first.close();
    var hiveOpenCount = 0;

    final reopened = await openAndroidMmkvBackedBox<dynamic>(
      name: name,
      isAndroid: true,
      store: store,
      openHive: () {
        hiveOpenCount++;
        return Future.error(StateError('Hive should not be opened'));
      },
    );

    expect(hiveOpenCount, 0);
    expect(reopened.get('value'), 42);
    await reopened.close();
  });

  test('model and typed values survive MMKV round trips', () async {
    final store = _MemoryAndroidMmkvStore();
    final userInfo = UserInfoData(
      isLogin: true,
      face: 'https://example.com/avatar.png',
      levelInfo: LevelInfo(
        currentLevel: 6,
        currentMin: 0,
        currentExp: 123,
        nextExp: 123,
      ),
      mid: 12345,
      money: 6.5,
      uname: 'Pili',
      vipStatus: 1,
      official: {'role': 1},
    );
    final userInfoBox = AndroidMmkvBackedBox<UserInfoData>(
      'userInfo',
      store: store,
      valueEncoder: AndroidMmkvStorageCodec.encodeUserInfoData,
      valueDecoder: AndroidMmkvStorageCodec.decodeUserInfoData,
    );
    await userInfoBox.put('userInfoCache', userInfo);

    final reopenedUserInfo = AndroidMmkvBackedBox<UserInfoData>(
      'userInfo',
      store: store,
      valueEncoder: AndroidMmkvStorageCodec.encodeUserInfoData,
      valueDecoder: AndroidMmkvStorageCodec.decodeUserInfoData,
    );
    expect(reopenedUserInfo.tryLoadFromMmkv(), isTrue);
    expect(reopenedUserInfo.get('userInfoCache'), userInfo);

    final rule = RuleFilter(
      ['spoiler'],
      [RegExp('^blocked', caseSensitive: false)],
      {'deadbeef'},
    );
    final localCache = AndroidMmkvBackedBox<dynamic>(
      'localCache',
      store: store,
      valueEncoder: AndroidMmkvStorageCodec.encodeLocalCacheValue,
      valueDecoder: AndroidMmkvStorageCodec.decodeLocalCacheValue,
    );
    await localCache.put('rule', rule);
    await localCache.put('ids', <int>{3, 2, 1});
    await localCache.put('bytes', Uint8List.fromList([0, 1, 2, 255]));

    final reopenedLocalCache = AndroidMmkvBackedBox<dynamic>(
      'localCache',
      store: store,
      valueEncoder: AndroidMmkvStorageCodec.encodeLocalCacheValue,
      valueDecoder: AndroidMmkvStorageCodec.decodeLocalCacheValue,
    );
    expect(reopenedLocalCache.tryLoadFromMmkv(), isTrue);
    final decodedRule = reopenedLocalCache.get('rule') as RuleFilter;
    expect(decodedRule.dmFilterString, rule.dmFilterString);
    expect(decodedRule.dmRegExp.single.pattern, rule.dmRegExp.single.pattern);
    expect(decodedRule.dmUid, rule.dmUid);
    expect(reopenedLocalCache.get('ids'), <int>{1, 2, 3});
    expect(
      reopenedLocalCache.get('bytes'),
      Uint8List.fromList([0, 1, 2, 255]),
    );

    await userInfoBox.close();
    await reopenedUserInfo.close();
    await localCache.close();
    await reopenedLocalCache.close();
  });

  test(
    'unsupported values fall back during migration and fail on writes',
    () async {
      final store = _MemoryAndroidMmkvStore();
      final name = _newHiveBoxName(hiveBoxNames, 'unsupported');
      final hive = await Hive.openBox<dynamic>(name);
      final unsupported = DateTime.utc(2026, 7, 10);
      await hive.put('date', unsupported);

      final box = await openAndroidMmkvBackedBox<dynamic>(
        name: name,
        isAndroid: true,
        store: store,
        openHive: () => Future.value(hive),
      );

      expect(identical(box, hive), isTrue);
      expect(
        store.getRaw(
          AndroidMmkvStore.metaBox,
          AndroidMmkvStore.migrationKey(name),
        ),
        isNull,
      );

      final mmkvBox = AndroidMmkvBackedBox<dynamic>('runtime', store: store);
      await expectLater(
        mmkvBox.put('date', unsupported),
        throwsA(isA<UnsupportedError>()),
      );
      await mmkvBox.close();
    },
  );

  test('native clear failures remain visible after a box is closed', () async {
    final box = AndroidMmkvBackedBox<dynamic>(
      'clearFailure',
      store: _MemoryAndroidMmkvStore(clearSucceeds: false),
    );
    await box.close();

    await expectLater(
      box.deleteFromDisk(),
      throwsA(isA<StateError>()),
    );
  });
}

String _newHiveBoxName(List<String> names, String suffix) {
  final name = 'mmkv_${suffix}_${DateTime.now().microsecondsSinceEpoch}';
  names.add(name);
  return name;
}

final class _MemoryAndroidMmkvStore implements AndroidMmkvStoreBackend {
  _MemoryAndroidMmkvStore({this.clearSucceeds = true});

  final bool clearSucceeds;
  final Map<String, Map<String, String>> _boxes = {};

  @override
  bool get isAvailable => true;

  @override
  bool clearBox(String name) {
    if (!clearSucceeds) return false;
    _boxes[name] = {};
    return true;
  }

  @override
  String? exportBox(String name) => jsonEncode(_boxes[name] ?? const {});

  @override
  String? getRaw(String name, String key) => _boxes[name]?[key];

  @override
  bool putRaw(String name, String key, String value) {
    (_boxes[name] ??= {})[key] = value;
    return true;
  }

  @override
  bool removeRaw(String name, String key) {
    _boxes[name]?.remove(key);
    return true;
  }

  @override
  bool replaceBox(String name, String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    _boxes[name] = decoded.map(
      (key, value) => MapEntry(key, value as String),
    );
    return true;
  }

  @override
  bool sync(String name) => true;
}
