import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';
import 'package:pili_plus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:pili_plus/utils/storage/favorite_order_store.dart';
import 'package:pili_plus/utils/storage/favorite_reply_store.dart';
import 'package:protobuf/protobuf.dart';

final class MyReplyController {
  MyReplyController(this._store, this._orderStore);

  static const _jsonEncoder = JsonEncoder.withIndent('    ');

  /// Local pin + sort overlay scope for favorited comments.
  static const String scope = 'reply';

  final FavoriteReplyStore _store;
  final FavoriteOrderStore _orderStore;
  final List<ReplyInfo> _replies = <ReplyInfo>[];

  int _invalidStoredCount = 0;

  UnmodifiableListView<ReplyInfo> get replies =>
      UnmodifiableListView<ReplyInfo>(_replies);

  int get count => _replies.length;

  int get invalidStoredCount => _invalidStoredCount;

  /// Ids in the current display order (pinned first).
  List<String> get displayIds =>
      _replies.map((reply) => reply.id.toString()).toList();

  bool isPinned(String id) => _orderStore.isPinned(scope, id);

  void reload() {
    final replies = <ReplyInfo>[];
    var invalidCount = 0;
    for (final data in _store.values) {
      try {
        final reply = ReplyInfo.fromBuffer(data);
        if (!_hasValidIdentity(reply)) {
          invalidCount++;
          continue;
        }
        replies.add(reply);
      } catch (_) {
        invalidCount++;
      }
    }
    replies.sort(_newestFirst);
    final ordered = _orderStore.displayOrder(
      scope,
      replies.map((reply) => reply.id.toString()),
    );
    final byId = {
      for (final reply in replies) reply.id.toString(): reply,
    };
    _replies
      ..clear()
      ..addAll([for (final id in ordered) byId[id]!]);
    _invalidStoredCount = invalidCount;
  }

  Future<void> togglePin(String id) async {
    if (_orderStore.isPinned(scope, id)) {
      await _orderStore.unpin(scope, id);
    } else {
      await _orderStore.pin(scope, id, displayIds);
    }
    reload();
  }

  Future<void> applyDrag(int oldIndex, int newIndex) async {
    await _orderStore.applyDrag(scope, oldIndex, newIndex, displayIds);
    reload();
  }

  String exportJson() {
    final current = _replies.map((reply) => reply.id.toString()).toSet();
    return _jsonEncoder.convert({
      'version': 1,
      'pinned': _orderStore.pinned(scope).where(current.contains).toList(),
      'order': displayIds,
      'replies': _replies.map((reply) => reply.toProto3Json()).toList(),
    });
  }

  Future<void> delete(String id) async {
    await _store.delete(id);
    _replies.removeWhere((reply) => reply.id.toString() == id);
  }

  Future<void> clear() async {
    await _store.clear();
    await _orderStore.clearScope(scope);
    _replies.clear();
    _invalidStoredCount = 0;
  }

  Future<FavoriteReplyImportSummary> importJson(Object? value) async {
    if (value is List) {
      return _importReplyList(value);
    }
    if (value is Map) {
      final replies = value['replies'];
      if (replies is! List) {
        throw const FormatException('导入内容必须是评论列表');
      }
      await _orderStore.importState(scope, value);
      return _importReplyList(replies);
    }
    throw const FormatException('导入内容必须是评论列表');
  }

  Future<FavoriteReplyImportSummary> _importReplyList(List<dynamic> value) async {
    final parsed = <String, ({ReplyInfo reply, Uint8List data})>{};
    var invalidCount = 0;
    var duplicateCount = 0;
    for (final item in value) {
      try {
        if (item is! Map) {
          throw const FormatException('评论条目必须是对象');
        }
        final json = <String, dynamic>{};
        for (final entry in item.entries) {
          final key = entry.key;
          if (key is! String) {
            throw const FormatException('评论字段名必须是字符串');
          }
          json[key] = entry.value;
        }
        final reply = ReplyInfo.create()..mergeFromProto3Json(json);
        if (!_hasValidIdentity(reply)) {
          throw const FormatException('评论 id、oid 或 type 无效');
        }
        final normalized = reply.deepCopy()
          ..unknownFields.clear()
          ..replies.clear()
          ..clearTrackInfo();
        final id = normalized.id.toString();
        if (parsed.remove(id) != null) {
          duplicateCount++;
        }
        parsed[id] = (reply: normalized, data: normalized.writeToBuffer());
      } catch (_) {
        invalidCount++;
      }
    }

    final ordered = parsed.entries.toList()
      ..sort((a, b) {
        final timeCompare = a.value.reply.ctime.compareTo(b.value.reply.ctime);
        return timeCompare != 0
            ? timeCompare
            : a.value.reply.id.compareTo(b.value.reply.id);
      });
    final updates = ordered
        .where((entry) => _store.containsKey(entry.key))
        .toList();
    final additions = ordered
        .where((entry) => !_store.containsKey(entry.key))
        .toList();
    final availableSlots = _store.maxEntries - _store.length;
    final additionCapacity = availableSlots > 0 ? availableSlots : 0;
    final overflow = additions.length - additionCapacity;
    final capacitySkippedCount = overflow > 0 ? overflow : 0;
    final kept =
        <MapEntry<String, ({ReplyInfo reply, Uint8List data})>>[
          ...updates,
          ...additions.skip(capacitySkippedCount),
        ]..sort((a, b) {
          final timeCompare = a.value.reply.ctime.compareTo(
            b.value.reply.ctime,
          );
          return timeCompare != 0
              ? timeCompare
              : a.value.reply.id.compareTo(b.value.reply.id);
        });

    await _store.putAll({
      for (final entry in kept) entry.key: entry.value.data,
    });
    reload();
    return FavoriteReplyImportSummary(
      totalCount: value.length,
      addedCount: kept.length - updates.length,
      updatedCount: updates.length,
      invalidCount: invalidCount,
      duplicateCount: duplicateCount,
      capacitySkippedCount: capacitySkippedCount,
      resultCount: count,
    );
  }

  static bool _hasValidIdentity(ReplyInfo reply) {
    return reply.hasId() &&
        reply.id > Int64.ZERO &&
        reply.hasOid() &&
        reply.oid > Int64.ZERO &&
        reply.hasType() &&
        reply.type > Int64.ZERO;
  }

  static int _newestFirst(ReplyInfo a, ReplyInfo b) {
    final timeCompare = b.ctime.compareTo(a.ctime);
    return timeCompare != 0 ? timeCompare : b.id.compareTo(a.id);
  }
}

final class FavoriteReplyImportSummary {
  const FavoriteReplyImportSummary({
    required this.totalCount,
    required this.addedCount,
    required this.updatedCount,
    required this.invalidCount,
    required this.duplicateCount,
    required this.capacitySkippedCount,
    required this.resultCount,
  });

  final int totalCount;
  final int addedCount;
  final int updatedCount;
  final int invalidCount;
  final int duplicateCount;
  final int capacitySkippedCount;
  final int resultCount;

  String get message {
    final details = <String>[
      '新增 $addedCount 条',
      '更新 $updatedCount 条',
      if (invalidCount > 0) '跳过无效条目 $invalidCount 条',
      if (duplicateCount > 0) '合并重复评论 $duplicateCount 条',
      if (capacitySkippedCount > 0) '因容量上限跳过 $capacitySkippedCount 条较旧评论',
    ];
    return '共读取 $totalCount 条，${details.join('，')}。当前共 $resultCount 条收藏。';
  }
}
