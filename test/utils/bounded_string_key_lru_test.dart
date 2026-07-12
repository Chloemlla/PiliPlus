import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pili_plus/utils/storage/bounded_string_key_lru.dart';
import 'package:pili_plus/utils/storage/reply_cache_store.dart';
import 'package:pili_plus/utils/storage/watch_progress_store.dart';
import 'package:pili_plus/utils/storage_key.dart';

void main() {
  late Directory hiveDirectory;
  late Box<int> progressBox;
  late Box<Uint8List> replyBox;
  late Box<dynamic> orderBox;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('pili_lru_test_');
    Hive.init(hiveDirectory.path);
  });

  setUp(() async {
    progressBox = await Hive.openBox<int>(
      'progress_${DateTime.now().microsecondsSinceEpoch}',
    );
    replyBox = await Hive.openBox<Uint8List>(
      'reply_${DateTime.now().microsecondsSinceEpoch}',
    );
    orderBox = await Hive.openBox<dynamic>(
      'order_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await progressBox.deleteFromDisk();
    await replyBox.deleteFromDisk();
    await orderBox.deleteFromDisk();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('BoundedStringKeyLru reports oldest keys for eviction', () {
    final lru = BoundedStringKeyLru(
      orderStore: orderBox,
      orderKey: 'order',
      maxEntries: 3,
      existingKeys: const ['a', 'b', 'c'],
    );
    expect(lru.keysToEvict(incoming: 1), ['a']);
  });

  test('WatchProgressStore evicts oldest writes beyond maxEntries', () async {
    final store = WatchProgressStore(
      progressBox,
      orderStore: orderBox,
      maxEntries: 3,
    );

    await store.put('1', 10);
    await store.put('2', 20);
    await store.put('3', 30);
    await store.put('4', 40);

    expect(progressBox.keys.map((key) => key.toString()).toSet(), {'2', '3', '4'});
    expect(store.get('1'), isNull);
    expect(store.get('4'), 40);
    expect(
      orderBox.get(LocalCacheKey.watchProgressWriteOrder),
      ['2', '3', '4'],
    );
  });

  test('WatchProgressStore refresh keeps existing key without eviction', () async {
    final store = WatchProgressStore(
      progressBox,
      orderStore: orderBox,
      maxEntries: 2,
    );
    await store.put('1', 10);
    await store.put('2', 20);
    await store.put('1', 11);
    expect(progressBox.length, 2);
    expect(store.get('1'), 11);
    expect(
      orderBox.get(LocalCacheKey.watchProgressWriteOrder),
      ['2', '1'],
    );
  });

  test('ReplyCacheStore evicts oldest writes beyond maxEntries', () async {
    final store = ReplyCacheStore(
      replyBox,
      orderStore: orderBox,
      maxEntries: 2,
    );
    await store.put('r1', Uint8List.fromList([1]));
    await store.put('r2', Uint8List.fromList([2]));
    await store.put('r3', Uint8List.fromList([3]));

    expect(replyBox.keys.map((key) => key.toString()).toSet(), {'r2', 'r3'});
    expect(
      orderBox.get(LocalCacheKey.replyWriteOrder),
      ['r2', 'r3'],
    );
  });
}
