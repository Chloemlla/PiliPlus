import 'dart:typed_data';

import 'package:hive_ce/hive.dart';
import 'package:pili_plus/utils/storage/bounded_string_key_lru.dart';
import 'package:pili_plus/utils/storage_key.dart';

final class ReplyCacheStore {
  ReplyCacheStore(
    Box<Uint8List>? box, {
    required Box<dynamic> orderStore,
    this.maxEntries = defaultMaxEntries,
  }) : _box = box,
       _lru = box == null
           ? null
           : BoundedStringKeyLru(
               orderStore: orderStore,
               orderKey: LocalCacheKey.replyWriteOrder,
               maxEntries: maxEntries,
               existingKeys: _seedKeys(orderStore, box),
             );

  static const int defaultMaxEntries = 500;

  final Box<Uint8List>? _box;
  final int maxEntries;
  final BoundedStringKeyLru? _lru;

  static Iterable<String> _seedKeys(
    Box<dynamic> orderStore,
    Box<Uint8List> box,
  ) {
    final raw = orderStore.get(LocalCacheKey.replyWriteOrder);
    if (raw is List && raw.isNotEmpty) {
      return raw
          .map((item) => item.toString())
          .where(box.containsKey);
    }
    return box.keys.map((key) => key.toString());
  }

  bool get isEnabled => _box != null;

  Iterable<Uint8List> get values => _box?.values ?? const [];

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

    final newKeys = values.keys.where((key) => !box.containsKey(key)).length;
    final evict = lru.keysToEvict(incoming: newKeys);
    if (evict.isNotEmpty) {
      await box.deleteAll(evict);
      await lru.removeAll(evict);
    }
    await box.putAll(values);
    await lru.touchAll(values.keys);
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
