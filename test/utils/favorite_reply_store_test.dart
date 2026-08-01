import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pili_plus/utils/storage/favorite_reply_migration.dart';
import 'package:pili_plus/utils/storage/favorite_reply_store.dart';
import 'package:pili_plus/utils/storage_key.dart';

void main() {
  late Directory hiveDirectory;
  late String favoriteBoxName;
  late String legacyBoxName;
  late Box<Uint8List> favoriteBox;
  late Box<Uint8List> legacyBox;
  late Box<dynamic> localCache;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pili_favorite_reply_test_',
    );
    Hive.init(hiveDirectory.path);
  });

  setUp(() async {
    final suffix = DateTime.now().microsecondsSinceEpoch;
    favoriteBoxName = 'favorite_reply_$suffix';
    legacyBoxName = 'legacy_reply_$suffix';
    favoriteBox = await Hive.openBox<Uint8List>(favoriteBoxName);
    legacyBox = await Hive.openBox<Uint8List>(legacyBoxName);
    localCache = await Hive.openBox<dynamic>('local_cache_$suffix');
  });

  tearDown(() async {
    if (!favoriteBox.isOpen) {
      favoriteBox = await Hive.openBox<Uint8List>(favoriteBoxName);
    }
    if (!legacyBox.isOpen) {
      legacyBox = await Hive.openBox<Uint8List>(legacyBoxName);
    }
    await favoriteBox.deleteFromDisk();
    await legacyBox.deleteFromDisk();
    await localCache.deleteFromDisk();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test(
    'legacy migration copies newest bounded entries and keeps source',
    () async {
      await legacyBox.putAll({
        for (var i = 1; i <= 3; i++) '$i': Uint8List.fromList([i]),
      });
      await localCache.put(LocalCacheKey.replyWriteOrder, ['1', '2', '3']);
      final store = FavoriteReplyStore(
        favoriteBox,
        orderStore: localCache,
        maxFavoriteEntries: 2,
      );

      await store.migrateLegacy(
        legacyBox: legacyBox,
        markerStore: localCache,
      );

      expect(favoriteBox.keys.map((key) => key.toString()).toSet(), {'2', '3'});
      expect(legacyBox.keys.map((key) => key.toString()).toSet(), {
        '1',
        '2',
        '3',
      });
      expect(
        localCache.get(LocalCacheKey.favoriteReplyMigrationV1),
        isTrue,
      );
    },
  );

  test('migration falls back to numeric reply-id order', () async {
    await legacyBox.putAll({
      '3': Uint8List.fromList([3]),
      '1': Uint8List.fromList([1]),
      '2': Uint8List.fromList([2]),
    });
    final store = FavoriteReplyStore(
      favoriteBox,
      orderStore: localCache,
      maxFavoriteEntries: 2,
    );

    await store.migrateLegacy(
      legacyBox: legacyBox,
      markerStore: localCache,
    );

    expect(favoriteBox.keys.map((key) => key.toString()).toSet(), {'2', '3'});
  });

  test('completed migration does not copy later automatic records', () async {
    await legacyBox.put('1', Uint8List.fromList([1]));
    final store = FavoriteReplyStore(
      favoriteBox,
      orderStore: localCache,
    );
    await store.migrateLegacy(
      legacyBox: legacyBox,
      markerStore: localCache,
    );
    await legacyBox.put('2', Uint8List.fromList([2]));

    await store.migrateLegacy(
      legacyBox: legacyBox,
      markerStore: localCache,
    );

    expect(store.containsKey('1'), isTrue);
    expect(store.containsKey('2'), isFalse);
  });

  test('favorite writes use independent order metadata', () async {
    await localCache.put(LocalCacheKey.replyWriteOrder, ['legacy']);
    final store = FavoriteReplyStore(
      favoriteBox,
      orderStore: localCache,
    );

    await store.put('1', Uint8List.fromList([1]));

    expect(localCache.get(LocalCacheKey.replyWriteOrder), ['legacy']);
    expect(localCache.get(LocalCacheKey.favoriteReplyWriteOrder), ['1']);
  });

  test(
    'migration while recording is disabled keeps automatic cache disabled',
    () async {
      await legacyBox.put('1', Uint8List.fromList([1]));
      final store = FavoriteReplyStore(
        favoriteBox,
        orderStore: localCache,
      );

      final automaticRecordBox = await prepareLegacyReplyStorage(
        shouldSaveReply: false,
        shouldMigrateFavorites: true,
        openLegacyBox: () async => legacyBox,
        destination: store,
        markerStore: localCache,
        onError: (_, _, {required operation, required reason}) {},
      );

      expect(automaticRecordBox, isNull);
      expect(store.containsKey('1'), isTrue);
      expect(localCache.get(LocalCacheKey.favoriteReplyMigrationV1), isTrue);
      expect(legacyBox.isOpen, isFalse);
    },
  );

  test(
    'completed migration skips the legacy box when recording is disabled',
    () async {
      await localCache.put(LocalCacheKey.favoriteReplyMigrationV1, true);
      final store = FavoriteReplyStore(
        favoriteBox,
        orderStore: localCache,
      );
      var legacyOpenAttempted = false;

      final automaticRecordBox = await prepareLegacyReplyStorage(
        shouldSaveReply: false,
        shouldMigrateFavorites: false,
        openLegacyBox: () async {
          legacyOpenAttempted = true;
          return legacyBox;
        },
        destination: store,
        markerStore: localCache,
        onError: (_, _, {required operation, required reason}) {},
      );

      expect(automaticRecordBox, isNull);
      expect(legacyOpenAttempted, isFalse);
    },
  );

  test('migration retry never evicts an explicit favorite', () async {
    await favoriteBox.put('9', Uint8List.fromList([9]));
    await localCache.put(LocalCacheKey.favoriteReplyWriteOrder, ['9']);
    await legacyBox.putAll({
      '1': Uint8List.fromList([1]),
      '2': Uint8List.fromList([2]),
    });
    final store = FavoriteReplyStore(
      favoriteBox,
      orderStore: localCache,
      maxFavoriteEntries: 2,
    );

    await store.migrateLegacy(
      legacyBox: legacyBox,
      markerStore: localCache,
    );

    expect(favoriteBox.keys.map((key) => key.toString()).toSet(), {'9', '2'});
    expect(legacyBox.keys.map((key) => key.toString()).toSet(), {'1', '2'});
    expect(localCache.get(LocalCacheKey.favoriteReplyMigrationV1), isTrue);
  });

  test(
    'best-effort migration reports failure without consuming the source',
    () async {
      await legacyBox.put('1', Uint8List.fromList([1]));
      final store = FavoriteReplyStore(
        favoriteBox,
        orderStore: localCache,
      );
      await favoriteBox.close();
      Object? reportedError;

      final succeeded = await tryMigrateLegacyReplyFavorites(
        destination: store,
        legacyBox: legacyBox,
        markerStore: localCache,
        onError: (error, _) => reportedError = error,
      );

      expect(succeeded, isFalse);
      expect(reportedError, isNotNull);
      expect(localCache.get(LocalCacheKey.favoriteReplyMigrationV1), isNull);
      expect(legacyBox.containsKey('1'), isTrue);
    },
  );

  test(
    'copy failure disables recording for the session and stays retryable',
    () async {
      await legacyBox.put('1', Uint8List.fromList([1]));
      final store = FavoriteReplyStore(
        favoriteBox,
        orderStore: localCache,
      );
      await favoriteBox.close();
      String? reportedOperation;
      String? reportedReason;

      final automaticRecordBox = await prepareLegacyReplyStorage(
        shouldSaveReply: true,
        shouldMigrateFavorites: true,
        openLegacyBox: () async => legacyBox,
        destination: store,
        markerStore: localCache,
        onError: (_, _, {required operation, required reason}) {
          reportedOperation = operation;
          reportedReason = reason;
        },
      );

      expect(automaticRecordBox, isNull);
      expect(reportedOperation, 'favoriteReply.legacyMigration');
      expect(reportedReason, 'favorite_reply_legacy_migration_failed');
      expect(localCache.get(LocalCacheKey.favoriteReplyMigrationV1), isNull);
      expect(legacyBox.isOpen, isFalse);

      legacyBox = await Hive.openBox<Uint8List>(legacyBoxName);
      expect(legacyBox.containsKey('1'), isTrue);
    },
  );

  test('legacy open failure keeps startup retryable', () async {
    final store = FavoriteReplyStore(
      favoriteBox,
      orderStore: localCache,
    );
    String? reportedOperation;
    String? reportedReason;

    final automaticRecordBox = await prepareLegacyReplyStorage(
      shouldSaveReply: true,
      shouldMigrateFavorites: true,
      openLegacyBox: () async => throw StateError('open failed'),
      destination: store,
      markerStore: localCache,
      onError: (_, _, {required operation, required reason}) {
        reportedOperation = operation;
        reportedReason = reason;
      },
    );

    expect(automaticRecordBox, isNull);
    expect(reportedOperation, 'favoriteReply.legacyOpen');
    expect(reportedReason, 'favorite_reply_legacy_open_failed');
    expect(localCache.get(LocalCacheKey.favoriteReplyMigrationV1), isNull);
  });
}
