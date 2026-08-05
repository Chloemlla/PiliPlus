import 'package:pili_plus/models/search/search_history_entry.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

abstract final class SearchHistoryStore {
  static const _key = 'syncEntries';

  static List<SearchHistoryEntry> read() {
    final raw = GStorage.historyWord.get(_key);
    if (raw is! List) {
      final legacy = GStorage.historyWord.get('cacheList');
      if (legacy is! List) return const [];
      return legacy
          .whereType<String>()
          .map(create)
          .toList(growable: false);
    }
    final result = <SearchHistoryEntry>[];
    for (final value in raw) {
      try {
        result.add(SearchHistoryEntry.fromJson(value));
      } on FormatException {
        // Ignore malformed entries while preserving the remaining history.
      }
    }
    return result;
  }

  static List<SearchHistoryEntry> visible() =>
      read().where((entry) => !entry.deleted).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  static SearchHistoryEntry create(String keyword) {
    final normalized = keyword.trim();
    final id = sha256.convert(utf8.encode(normalized.toLowerCase())).toString();
    return SearchHistoryEntry(
      id: id,
      keyword: normalized,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  static Future<void> upsert(String keyword) async {
    final entry = create(keyword);
    final entries = {
      for (final item in read()) item.id: item,
    };
    entries[entry.id] = entry;
    await write(entries.values);
  }

  static Future<void> tombstone(String keyword) async {
    final entry = create(keyword);
    final entries = {for (final item in read()) item.id: item};
    entries[entry.id] = SearchHistoryEntry(
      id: entry.id,
      keyword: entry.keyword,
      updatedAt: DateTime.now().toUtc(),
      deleted: true,
    );
    await write(entries.values);
  }

  static Future<void> tombstoneAll() async {
    final now = DateTime.now().toUtc();
    await write([
      for (final entry in read())
        SearchHistoryEntry(
          id: entry.id,
          keyword: entry.keyword,
          updatedAt: now,
          deleted: true,
        ),
    ]);
  }

  static Future<void> write(Iterable<SearchHistoryEntry> entries) {
    return GStorage.historyWord.put(
      _key,
      entries.map((entry) => entry.toJson()).toList(growable: false),
    );
  }

  static List<SearchHistoryEntry> merge(
    Iterable<SearchHistoryEntry> local,
    Iterable<SearchHistoryEntry> remote,
  ) {
    final merged = <String, SearchHistoryEntry>{};
    for (final entry in [...local, ...remote]) {
      final previous = merged[entry.id];
      if (previous == null || entry.updatedAt.isAfter(previous.updatedAt)) {
        merged[entry.id] = entry;
      }
    }
    return merged.values
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
}
