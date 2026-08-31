import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pili_plus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:pili_plus/pages/my_reply/controller.dart';
import 'package:pili_plus/utils/storage/favorite_order_store.dart';
import 'package:pili_plus/utils/storage/favorite_reply_store.dart';
import 'package:pili_plus/utils/storage_key.dart';

void main() {
  late Directory hiveDirectory;
  late Box<Uint8List> favoriteBox;
  late Box<dynamic> localCache;
  late FavoriteReplyStore store;
  late MyReplyController controller;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pili_my_reply_controller_test_',
    );
    Hive.init(hiveDirectory.path);
  });

  setUp(() async {
    final suffix = DateTime.now().microsecondsSinceEpoch;
    favoriteBox = await Hive.openBox<Uint8List>('favorite_reply_$suffix');
    localCache = await Hive.openBox<dynamic>('local_cache_$suffix');
    store = FavoriteReplyStore(
      favoriteBox,
      orderStore: localCache,
      maxFavoriteEntries: 2,
    );
    controller = MyReplyController(
      store,
      FavoriteOrderStore(localCache),
    )..reload();
  });

  tearDown(() async {
    await favoriteBox.deleteFromDisk();
    await localCache.deleteFromDisk();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('import validates each item and de-duplicates by reply id', () async {
    final summary = await controller.importJson([
      _replyJson(id: 1, ctime: 10),
      'not an object',
      {'id': 'broken'},
      _replyJson(id: 2, ctime: 20),
      _replyJson(id: 1, ctime: 30),
    ]);

    expect(summary.totalCount, 5);
    expect(summary.addedCount, 2);
    expect(summary.updatedCount, 0);
    expect(summary.invalidCount, 2);
    expect(summary.duplicateCount, 1);
    expect(controller.replies.map((reply) => reply.id.toInt()), [1, 2]);
    expect(controller.replies.first.ctime.toInt(), 30);
  });

  test('invalid import entries preserve existing favorites', () async {
    await controller.importJson([_replyJson(id: 1, ctime: 10)]);

    final summary = await controller.importJson([
      null,
      {'oid': '10', 'type': '1'},
    ]);

    expect(summary.invalidCount, 2);
    expect(summary.addedCount, 0);
    expect(store.containsKey('1'), isTrue);
    expect(controller.count, 1);
  });

  test(
    'import keeps newest comments when bounded capacity is exceeded',
    () async {
      final summary = await controller.importJson([
        _replyJson(id: 3, ctime: 30),
        _replyJson(id: 1, ctime: 10),
        _replyJson(id: 2, ctime: 20),
      ]);

      expect(summary.capacitySkippedCount, 1);
      expect(controller.replies.map((reply) => reply.id.toInt()), [3, 2]);
      expect(store.containsKey('1'), isFalse);
    },
  );

  test('capacity-limited import never evicts existing favorites', () async {
    await controller.importJson([
      _replyJson(id: 1, ctime: 10),
      _replyJson(id: 2, ctime: 20),
    ]);

    final summary = await controller.importJson([
      _replyJson(id: 3, ctime: 30),
    ]);

    expect(summary.addedCount, 0);
    expect(summary.capacitySkippedCount, 1);
    expect(store.containsKey('1'), isTrue);
    expect(store.containsKey('2'), isTrue);
    expect(store.containsKey('3'), isFalse);
  });

  test('updated import, delete, clear and export stay synchronized', () async {
    await controller.importJson([
      _replyJson(id: 1, ctime: 10),
      _replyJson(id: 2, ctime: 20),
    ]);
    final summary = await controller.importJson([
      _replyJson(id: 1, ctime: 30),
    ]);

    expect(summary.updatedCount, 1);
    expect(controller.replies.first.id.toInt(), 1);
    expect(controller.exportJson(), contains('"id": "1"'));

    await controller.delete('1');
    expect(controller.count, 1);
    expect(store.containsKey('1'), isFalse);

    await controller.clear();
    expect(controller.count, 0);
    expect(store.length, 0);
    expect(
      localCache.get(LocalCacheKey.favoriteReplyWriteOrder),
      isEmpty,
    );
  });

  test('top-level import must be a list', () async {
    await expectLater(
      controller.importJson({'id': '1'}),
      throwsFormatException,
    );
  });

  test('pin brings a comment to the top and export includes state', () async {
    await controller.importJson([
      _replyJson(id: 1, ctime: 10),
      _replyJson(id: 2, ctime: 20),
    ]);

    await controller.togglePin('1');
    expect(controller.replies.map((reply) => reply.id.toInt()), [1, 2]);
    expect(controller.isPinned('1'), isTrue);

    final exported = jsonDecode(controller.exportJson()) as Map<String, dynamic>;
    expect(exported['pinned'], ['1']);
    expect((exported['replies'] as List).length, 2);

    await controller.togglePin('1');
    expect(controller.isPinned('1'), isFalse);
    expect(controller.replies.map((reply) => reply.id.toInt()), [1, 2]);
  });

  test('drag reorders comments and flips pin across the pinned boundary',
      () async {
    await controller.importJson([
      _replyJson(id: 1, ctime: 10),
      _replyJson(id: 2, ctime: 20),
    ]);
    await controller.togglePin('2');

    await controller.applyDrag(0, 2);
    expect(controller.replies.map((reply) => reply.id.toInt()), [1, 2]);
    expect(controller.isPinned('1'), isTrue);
    expect(controller.isPinned('2'), isFalse);
  });

  test('new-format export/import restores pin and order state', () async {
    await controller.importJson([
      _replyJson(id: 1, ctime: 10),
      _replyJson(id: 2, ctime: 20),
    ]);
    await controller.togglePin('2');
    await controller.applyDrag(1, 0);
    expect(controller.replies.map((reply) => reply.id.toInt()), [1, 2]);
    expect(controller.isPinned('1'), isTrue);

    final exported = jsonDecode(controller.exportJson());
    final restored = MyReplyController(store, FavoriteOrderStore(localCache));
    await restored.importJson(exported);

    expect(restored.replies.map((reply) => reply.id.toInt()), [1, 2]);
    expect(restored.isPinned('1'), isTrue);
  });
}

Map<String, dynamic> _replyJson({required int id, required int ctime}) {
  return Map<String, dynamic>.from(
    ReplyInfo(
          id: Int64(id),
          oid: Int64(100 + id),
          type: Int64.ONE,
          ctime: Int64(ctime),
        ).toProto3Json()!
        as Map,
  );
}
