import 'dart:convert';

/// A search entry keeps its deletion marker so sync cannot resurrect it.
final class SearchHistoryEntry {
  const SearchHistoryEntry({
    required this.id,
    required this.keyword,
    required this.updatedAt,
    this.deleted = false,
  });

  final String id;
  final String keyword;
  final DateTime updatedAt;
  final bool deleted;

  factory SearchHistoryEntry.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('Invalid search history entry');
    final id = value['id']?.toString() ?? '';
    final keyword = value['keyword']?.toString() ?? '';
    final updatedAt = DateTime.tryParse(value['updatedAt']?.toString() ?? '');
    if (id.isEmpty || keyword.isEmpty || updatedAt == null) {
      throw const FormatException('Invalid search history entry fields');
    }
    return SearchHistoryEntry(
      id: id,
      keyword: keyword,
      updatedAt: updatedAt.toUtc(),
      deleted: value['deleted'] == true,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'keyword': keyword,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };

  String encode() => jsonEncode(toJson());
}
