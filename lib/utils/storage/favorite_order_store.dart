import 'package:hive_ce/hive.dart';

/// Persists per-scope manual pin + drag order used as a local overlay on top
/// of cloud-sourced lists (favorited comments, favorite folders, and videos
/// inside a favorite folder).
///
/// Scope is a namespacing string (e.g. 'reply', 'favFolder',
/// 'favDetail:123456'). [order] is the full display order of ids; [pinned] is
/// the ordered subset that stays pinned on top.
base class FavoriteOrderStore {
  FavoriteOrderStore(this._box);

  static const String _orderPrefix = 'favOrder.';
  static const String _pinPrefix = 'favPin.';

  final Box<dynamic> _box;

  static String _orderKey(String scope) => _orderPrefix + scope;
  static String _pinKey(String scope) => _pinPrefix + scope;

  List<String> _read(String key) {
    final raw = _box.get(key);
    if (raw is List) {
      return raw.map((item) => item.toString()).toList();
    }
    return const <String>[];
  }

  /// The persisted full display order (ids, pinned first).
  List<String> order(String scope) => _read(_orderKey(scope));

  /// The persisted pinned ids, in pin order.
  List<String> pinned(String scope) => _read(_pinKey(scope));

  bool isPinned(String scope, String id) => pinned(scope).contains(id);

  Future<void> _save(
    String scope,
    List<String> order,
    List<String> pinned,
  ) async {
    final available = order.toSet();
    await _box.put(_orderKey(scope), order);
    await _box.put(
      _pinKey(scope),
      pinned.where(available.contains).toList(),
    );
  }

  /// Computes the display order for [availableIds]: pinned ids first (in pin
  /// order), then non-pinned ids in manual order, then any id not recorded yet
  /// (e.g. freshly favorited) appended.
  List<String> displayOrder(String scope, Iterable<String> availableIds) {
    final available = availableIds.toSet();
    final pinnedIds = pinned(scope).where(available.contains).toList();
    final pinnedSet = pinnedIds.toSet();
    final manual = order(scope);
    final result = <String>[];
    final seen = <String>{};
    for (final id in pinnedIds) {
      if (seen.add(id)) result.add(id);
    }
    for (final id in manual) {
      if (!pinnedSet.contains(id) && available.contains(id) && seen.add(id)) {
        result.add(id);
      }
    }
    for (final id in availableIds) {
      if (seen.add(id)) result.add(id);
    }
    return result;
  }

  /// Applies a user drag on the displayed list. The first N positions (N = the
  /// pinned count before the drag) stay pinned; dragging across the boundary
  /// flips the dragged item's pin state, keeping the pinned section size
  /// stable.
  Future<void> applyDrag(
    String scope,
    int oldIndex,
    int newIndex,
    Iterable<String> availableIds,
  ) async {
    final current = displayOrder(scope, availableIds);
    if (oldIndex < 0 || oldIndex >= current.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > current.length) newIndex = current.length;
    final id = current.removeAt(oldIndex);
    current.insert(newIndex, id);
    final pinnedCount = pinned(scope).length;
    await _save(scope, current, current.take(pinnedCount).toList());
  }

  /// Pins [id] to the top of the pinned section.
  Future<void> pin(
    String scope,
    String id,
    Iterable<String> availableIds,
  ) async {
    final current = displayOrder(scope, availableIds)..remove(id);
    final nextPinned = pinned(scope)..remove(id)..insert(0, id);
    await _save(scope, [id, ...current], nextPinned);
  }

  /// Unpins [id]; it keeps its manual position and becomes the first
  /// non-pinned item.
  Future<void> unpin(String scope, String id) async {
    final nextPinned = pinned(scope)..remove(id);
    await _save(scope, order(scope), nextPinned);
  }

  Future<void> clearScope(String scope) async {
    await _box.delete(_orderKey(scope));
    await _box.delete(_pinKey(scope));
  }

  /// Exports the local pin + order state for [scope].
  Map<String, dynamic> exportState(String scope) => {
    'version': 1,
    'pinned': pinned(scope),
    'order': order(scope),
  };

  /// Imports local pin + order state, returning how many ids were recorded.
  Future<int> importState(String scope, Object? raw) async {
    if (raw is! Map) {
      throw const FormatException('导入内容必须是对象');
    }
    final data = Map<String, dynamic>.from(raw);
    if (data['version'] != 1) {
      throw const FormatException('不支持的排序状态版本');
    }
    final order = _toIdList(data['order'], field: 'order');
    final pinned = _toIdList(data['pinned'], field: 'pinned')
        .where(order.contains)
        .toList();
    await _save(scope, order, pinned);
    return order.length;
  }

  static List<String> _toIdList(Object? raw, {required String field}) {
    if (raw == null) return const <String>[];
    if (raw is! List) {
      throw FormatException('$field 必须是数组');
    }
    return raw.map((item) => item.toString()).toList();
  }
}
