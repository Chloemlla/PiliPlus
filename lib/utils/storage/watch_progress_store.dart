import 'package:hive_ce/hive.dart';

final class WatchProgressStore {
  const WatchProgressStore(this._box);

  final Box<int> _box;

  int? get(String key) => _box.get(key);

  Future<void> put(String key, int progress) => _box.put(key, progress);

  Future<void> delete(String key) => _box.delete(key);

  Future<void> deleteAll(Iterable<String> keys) => _box.deleteAll(keys);
}
