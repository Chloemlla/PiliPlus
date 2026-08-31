import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:pili_plus/utils/storage/favorite_order_store.dart';

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> box;
  late FavoriteOrderStore store;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pili_favorite_order_store_test_',
    );
    Hive.init(hiveDirectory.path);
  });

  setUp(() async {
    final suffix = DateTime.now().microsecondsSinceEpoch;
    box = await Hive.openBox<dynamic>('favorite_order_$suffix');
    store = FavoriteOrderStore(box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  const scope = 'testScope';

  test('empty state returns the available ids in order', () {
    expect(store.displayOrder(scope, ['a', 'b', 'c']), ['a', 'b', 'c']);
  });

  test('pin brings an id to the top and persists', () async {
    await store.pin(scope, 'b', ['a', 'b', 'c']);
    expect(store.displayOrder(scope, ['a', 'b', 'c']), ['b', 'a', 'c']);
    expect(store.isPinned(scope, 'b'), isTrue);
    expect(store.pinned(scope), ['b']);
  });

  test('unpin keeps position as the first non-pinned item', () async {
    await store.pin(scope, 'c', ['a', 'b', 'c']);
    await store.unpin(scope, 'c');
    expect(store.displayOrder(scope, ['a', 'b', 'c']), ['c', 'a', 'b']);
    expect(store.isPinned(scope, 'c'), isFalse);
  });

  test('drag reorders non-pinned ids', () async {
    await store.applyDrag(scope, 1, 2, ['a', 'b', 'c']);
    expect(store.displayOrder(scope, ['a', 'b', 'c']), ['a', 'c', 'b']);
  });

  test('dragging a pinned id past the boundary flips pin state', () async {
    await store.pin(scope, 'a', ['a', 'b', 'c']);
    await store.applyDrag(scope, 0, 2, ['a', 'b', 'c']);
    expect(store.displayOrder(scope, ['a', 'b', 'c']), ['b', 'c', 'a']);
    expect(store.isPinned(scope, 'a'), isFalse);
    expect(store.isPinned(scope, 'b'), isTrue);
  });

  test('stale ids from deletes are filtered out of the display', () async {
    await store.pin(scope, 'b', ['a', 'b', 'c']);
    expect(store.displayOrder(scope, ['a', 'c']), ['b', 'a', 'c']);
  });

  test('export/import round-trips pin and order state', () async {
    await store.pin(scope, 'b', ['a', 'b', 'c']);
    await store.applyDrag(scope, 1, 2, ['a', 'b', 'c']);
    final exported = jsonDecode(
      jsonEncode(store.exportState(scope)),
    );

    await store.clearScope(scope);
    expect(store.displayOrder(scope, ['a', 'b', 'c']), ['a', 'b', 'c']);

    final imported = await store.importState(scope, exported);
    expect(imported, 3);
    expect(store.displayOrder(scope, ['a', 'b', 'c']), ['b', 'c', 'a']);
    expect(store.isPinned(scope, 'b'), isTrue);
  });

  test('import rejects a missing version', () async {
    await expectLater(
      store.importState(scope, {'pinned': [], 'order': []}),
      throwsFormatException,
    );
  });
}
