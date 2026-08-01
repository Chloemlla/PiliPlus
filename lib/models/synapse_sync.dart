import 'dart:collection';

/// A search entry that can survive merges and deletes across devices.
final class SynapseSearchRecord {
  const SynapseSearchRecord({
    required this.id,
    required this.keyword,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final String keyword;
  final DateTime updatedAt;
  final bool deleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'keyword': keyword,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deleted': deleted,
  };

  factory SynapseSearchRecord.fromJson(Map json) => SynapseSearchRecord(
    id: json['id'].toString(),
    keyword: json['keyword']?.toString() ?? json['query']?.toString() ?? '',
    updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deleted: json['deleted'] == true || json['isDeleted'] == true,
  );

  SynapseSearchRecord copyWith({DateTime? updatedAt, bool? deleted}) =>
      SynapseSearchRecord(
        id: id,
        keyword: keyword,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );
}

abstract final class SynapseSearchMerge {
  static List<SynapseSearchRecord> merge(
    Iterable<SynapseSearchRecord> local,
    Iterable<SynapseSearchRecord> remote,
  ) {
    final merged = <String, SynapseSearchRecord>{};
    for (final item in [...local, ...remote]) {
      final previous = merged[item.id];
      if (previous == null || item.updatedAt.isAfter(previous.updatedAt)) {
        merged[item.id] = item;
      }
    }
    return UnmodifiableListView(
      merged.values
          .where((item) => !item.deleted && item.keyword.isNotEmpty)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
  }
}

enum SynapseSettingChoice { remote, local, merge }

final class SynapseSettingConflict {
  const SynapseSettingConflict({
    required this.key,
    required this.localValue,
    required this.remoteValue,
  });

  final String key;
  final Object? localValue;
  final Object? remoteValue;
}

final class SynapseRemoteSnapshot {
  const SynapseRemoteSnapshot({
    required this.search,
    required this.settings,
  });

  final List<SynapseSearchRecord> search;
  final Map<String, Object?> settings;

  factory SynapseRemoteSnapshot.fromJson(Map json) {
    final search = json['records'] ?? json['search'];
    final settings = json['settings'];
    return SynapseRemoteSnapshot(
      search: search is Iterable
          ? [
              for (final item in search)
                if (item is Map) SynapseSearchRecord.fromJson(item),
            ]
          : const [],
      settings: settings is Map
          ? {for (final entry in settings.entries) entry.key.toString(): entry.value}
          : const {},
    );
  }
}

