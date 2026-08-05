import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:pili_plus/utils/storage/bounded_string_key_lru.dart';

/// A bounded, write-ordered store for protobuf or other binary payloads.
base class BoundedUint8ListStore {
  BoundedUint8ListStore(
    Box<Uint8List>? box, {
    required Box<dynamic> orderStore,
    required String orderKey,
    required this.maxEntries,
  }) : _box = box,
       _lru = box == null
           ? null
           : BoundedStringKeyLru(
               orderStore: orderStore,
               orderKey: orderKey,
               maxEntries: maxEntries,
               existingKeys: _seedKeys(orderStore, box, orderKey),
             );

  final Box<Uint8List>? _box;
  final int maxEntries;
  final BoundedStringKeyLru? _lru;

  static Iterable<String> _seedKeys(
    Box<dynamic> orderStore,
    Box<Uint8List> box,
    String orderKey,
  ) {
    final boxKeys = box.keys.map((key) => key.toString()).toList();
    final raw = orderStore.get(orderKey);
    if (raw is! List || raw.isEmpty) return boxKeys;

    final seeded = raw
        .map((item) => item.toString())
        .where(box.containsKey)
        .toList();
    final seen = seeded.toSet();
    return [...seeded, ...boxKeys.where(seen.add)];
  }

  bool get isEnabled => _box != null;

  int get length => _box?.length ?? 0;

  bool containsKey(String key) => _box?.containsKey(key) ?? false;

  Iterable<Uint8List> get values => _box?.values ?? const <Uint8List>[];

  Future<void> trim() async {
    final box = _box;
    final lru = _lru;
    if (box == null || lru == null) return;

    final evict = lru.keysToEvict();
    if (evict.isNotEmpty) {
      await box.deleteAll(evict);
      await lru.removeAll(evict);
    }
  }

  Future<void> put(String key, Uint8List value) async {
    final box = _box;
    final lru = _lru;
    if (box == null || lru == null) return;

    final evict = lru.keysToEvict(incoming: box.containsKey(key) ? 0 : 1);
    if (evict.isNotEmpty) {
      await box.deleteAll(evict);
      await lru.removeAll(evict);
    }
    await box.put(key, value);
    await lru.touch(key);
  }

  Future<void> putAll(Map<String, Uint8List> values) async {
    final box = _box;
    final lru = _lru;
    if (box == null || lru == null || values.isEmpty) return;

    final evict = lru.keysToEvictForWrite(values.keys);
    if (evict.isNotEmpty) {
      await box.deleteAll(evict);
      await lru.removeAll(evict);
    }
    final keptKeys = lru.keysToKeepForWrite(values.keys);
    if (keptKeys.isEmpty) return;
    await box.putAll({
      for (final key in keptKeys) key: values[key]!,
    });
    await lru.touchAll(keptKeys);
  }

  Future<void> delete(String key) async {
    await _box?.delete(key);
    await _lru?.remove(key);
  }

  Future<void> clear() async {
    await _box?.clear();
    await _lru?.clear();
  }
}
