import 'package:hive_ce/hive.dart';
import 'package:pili_plus/utils/storage/bounded_string_key_lru.dart';
import 'package:pili_plus/utils/storage_key.dart';

final class WatchProgressStore {
  WatchProgressStore(
    this._box, {
    required Box<dynamic> orderStore,
    this.maxEntries = defaultMaxEntries,
  }) : _lru = BoundedStringKeyLru(
         orderStore: orderStore,
         orderKey: LocalCacheKey.watchProgressWriteOrder,
         maxEntries: maxEntries,
         existingKeys: _box.keys.map((key) => key.toString()),
       );

  static const int defaultMaxEntries = 2000;

  final Box<int> _box;
  final int maxEntries;
  final BoundedStringKeyLru _lru;

  int? get(String key) => _box.get(key);

  Future<void> put(String key, int progress) async {
    final evict = _lru.keysToEvict(incoming: _box.containsKey(key) ? 0 : 1);
    if (evict.isNotEmpty) {
      await _box.deleteAll(evict);
      await _lru.removeAll(evict);
    }
    await _box.put(key, progress);
    await _lru.touch(key);
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
    await _lru.remove(key);
  }

  Future<void> deleteAll(Iterable<String> keys) async {
    final list = keys.toList(growable: false);
    await _box.deleteAll(list);
    await _lru.removeAll(list);
  }
}
