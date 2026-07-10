import 'dart:typed_data';

import 'package:hive_ce/hive.dart';

final class ReplyCacheStore {
  const ReplyCacheStore(this._box);

  final Box<Uint8List>? _box;

  bool get isEnabled => _box != null;

  Iterable<Uint8List> get values => _box?.values ?? const [];

  Future<void> put(String key, Uint8List value) async => _box?.put(key, value);

  Future<void> putAll(Map<String, Uint8List> values) async =>
      _box?.putAll(values);

  Future<void> delete(String key) async => _box?.delete(key);

  Future<void> clear() async => _box?.clear();
}
