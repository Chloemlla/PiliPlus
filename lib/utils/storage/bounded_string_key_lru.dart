import 'package:hive_ce/hive.dart';

/// Approximate write-order LRU for string-keyed boxes.
///
/// [orderStore] persists the write order under [orderKey]. When [maxEntries]
/// is exceeded after a write, the oldest written keys are deleted from [box].
final class BoundedStringKeyLru {
  BoundedStringKeyLru({
    required Box<dynamic> orderStore,
    required this.orderKey,
    required this.maxEntries,
    required Iterable<String> existingKeys,
  }) : _orderStore = orderStore {
    final raw = orderStore.get(orderKey);
    final persisted = raw is List
        ? raw.map((item) => item.toString()).toList()
        : <String>[];
    final existing = existingKeys.toList(growable: false);
    final next = <String>[];
    final seen = <String>{};
    for (final key in persisted) {
      if (existing.contains(key) && seen.add(key)) {
        next.add(key);
      }
    }
    for (final key in existing) {
      if (seen.add(key)) {
        next.add(key);
      }
    }
    _order.addAll(next);
  }

  final Box<dynamic> _orderStore;
  final String orderKey;
  final int maxEntries;
  final List<String> _order = <String>[];

  List<String> get order => List<String>.unmodifiable(_order);

  Future<void> touch(String key) async {
    _order
      ..remove(key)
      ..add(key);
    await _persist();
  }

  Future<void> touchAll(Iterable<String> keys) async {
    for (final key in keys) {
      _order
        ..remove(key)
        ..add(key);
    }
    await _persist();
  }

  Future<void> remove(String key) async {
    if (_order.remove(key)) {
      await _persist();
    }
  }

  Future<void> removeAll(Iterable<String> keys) async {
    var changed = false;
    for (final key in keys) {
      if (_order.remove(key)) {
        changed = true;
      }
    }
    if (changed) {
      await _persist();
    }
  }

  Future<void> clear() async {
    if (_order.isEmpty) return;
    _order.clear();
    await _persist();
  }

  /// Returns keys that must be deleted before writing [incomingKeys] while
  /// keeping the newest [maxEntries] keys in deterministic iteration order.
  List<String> keysToEvictForWrite(Iterable<String> incomingKeys) {
    final incoming = incomingKeys.toList(growable: false);
    final next = _orderAfterTouch(incoming);
    final retained = next.skip(_overflowStart(next.length)).toSet();
    return _order
        .where((key) => !retained.contains(key))
        .toList(growable: false);
  }

  /// Returns the incoming keys that fit after the write, in write order.
  List<String> keysToKeepForWrite(Iterable<String> incomingKeys) {
    final incoming = incomingKeys.toList(growable: false);
    final incomingSet = incoming.toSet();
    final next = _orderAfterTouch(incoming);
    return next
        .skip(_overflowStart(next.length))
        .where(incomingSet.contains)
        .toList(growable: false);
  }

  /// Returns keys that must be deleted to keep [maxEntries].
  List<String> keysToEvict({int incoming = 0}) {
    final overflow = _order.length + incoming - maxEntries;
    if (overflow <= 0) return const [];
    return _order.take(overflow).toList(growable: false);
  }

  Future<void> _persist() => _orderStore.put(orderKey, List<String>.of(_order));

  List<String> _orderAfterTouch(Iterable<String> incomingKeys) {
    final next = List<String>.of(_order);
    for (final key in incomingKeys) {
      next
        ..remove(key)
        ..add(key);
    }
    return next;
  }

  int _overflowStart(int length) {
    final start = length - maxEntries;
    return start > 0 ? start : 0;
  }
}
