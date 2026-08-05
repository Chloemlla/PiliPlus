import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:pili_plus/models/video_bookmark.dart';
import 'package:pili_plus/utils/id_utils.dart';
import 'package:uuid/v4.dart';

class VideoBookmarkService {
  static const String boxName = 'videoBookmarks';
  static const int exportVersion = 1;
  static const String exportApp = 'PiliPlus';
  static const int maxBookmarksPerVideo = 200;
  static const int maxImportEntries = 10000;
  static const int maxImportJsonBytes = 8 * 1024 * 1024;

  static Box<VideoBookmark>? _box;
  static Object? _lastInitializationError;

  static bool get isInitialized => _box?.isOpen == true;

  static Object? get lastInitializationError => _lastInitializationError;

  /// Opens bookmark storage without making a feature failure fatal to startup.
  static Future<bool> init() async {
    if (_box?.isOpen == true) {
      return true;
    }
    try {
      if (!Hive.isAdapterRegistered(100)) {
        Hive.registerAdapter(VideoBookmarkAdapter());
      }
      _box = await Hive.openBox<VideoBookmark>(boxName);
      _lastInitializationError = null;
      return true;
    } catch (error) {
      _box = null;
      _lastInitializationError = error;
      return false;
    }
  }

  static Box<VideoBookmark> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'VideoBookmarkService is unavailable: '
        '${_lastInitializationError ?? 'call init() first'}',
      );
    }
    return _box!;
  }

  static String _generateId() {
    late String id;
    do {
      id = 'bm_${const UuidV4().generate()}';
    } while (box.containsKey(id));
    return id;
  }

  /// Get all bookmarks for a specific video
  static List<VideoBookmark> getBookmarksForVideo(String bvid) {
    return box.values.where((b) => b.bvid == bvid).toList()
      ..sort((a, b) => a.timestampSeconds.compareTo(b.timestampSeconds));
  }

  /// Get bookmark count for a specific video
  static int getBookmarkCountForVideo(String bvid) {
    return box.values.where((b) => b.bvid == bvid).length;
  }

  /// Check if max bookmarks reached for a video
  static bool canAddBookmark(String bvid) {
    return getBookmarkCountForVideo(bvid) < maxBookmarksPerVideo;
  }

  /// Add a new bookmark
  static Future<VideoBookmark?> addBookmark({
    required String bvid,
    required String videoTitle,
    int? authorMid,
    required int timestampSeconds,
    String? name,
    String? note,
  }) async {
    final normalizedBvid = bvid.trim();
    final normalizedVideoTitle = videoTitle.trim();
    _validateNewBookmarkMetadata(
      bvid: normalizedBvid,
      videoTitle: normalizedVideoTitle,
      authorMid: authorMid,
    );
    if (!canAddBookmark(normalizedBvid)) {
      return null;
    }

    final safeTimestamp = timestampSeconds < 0 ? 0 : timestampSeconds;
    final trimmedName = name?.trim();
    final trimmedNote = note?.trim();
    final now = DateTime.now();
    final bookmarkName = trimmedName == null || trimmedName.isEmpty
        ? '标记 @ ${VideoBookmark.formatTimestamp(safeTimestamp)}'
        : trimmedName;

    final bookmark = _normalizeBookmark(
      VideoBookmark(
        id: _generateId(),
        bvid: normalizedBvid,
        videoTitle: normalizedVideoTitle,
        authorMid: authorMid,
        timestampSeconds: safeTimestamp,
        name: bookmarkName,
        note: trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
        createdAt: now,
      ),
    );

    await box.put(bookmark.id, bookmark);
    return bookmark;
  }

  /// Update a bookmark's name or note
  static Future<void> updateBookmark(VideoBookmark bookmark) async {
    final existing = box.get(bookmark.id);
    if (existing == null) {
      throw StateError('Bookmark ${bookmark.id} does not exist.');
    }
    await box.put(
      existing.id,
      _normalizeBookmark(
        existing.copyWithDetails(name: bookmark.name, note: bookmark.note),
      ),
    );
  }

  /// Delete a bookmark by ID
  static Future<void> deleteBookmark(String id) async {
    await box.delete(id);
  }

  /// Delete all bookmarks for a specific video
  static Future<void> deleteBookmarksForVideo(String bvid) async {
    final keysToDelete = box.values
        .where((b) => b.bvid == bvid)
        .map((b) => b.id)
        .toList();
    await box.deleteAll(keysToDelete);
  }

  /// Get all bookmarks
  static List<VideoBookmark> getAllBookmarks() {
    return box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Search bookmarks by name or note
  static List<VideoBookmark> searchBookmarks(String query) {
    return getBookmarksSorted(
      sortType: SortType.mostRecent,
      searchQuery: query,
    );
  }

  /// Get bookmarks grouped by video
  static Map<String, List<VideoBookmark>> getBookmarksGroupedByVideo() {
    final grouped = <String, List<VideoBookmark>>{};
    for (final bookmark in box.values) {
      grouped.putIfAbsent(bookmark.bvid, () => []).add(bookmark);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.timestampSeconds.compareTo(b.timestampSeconds));
    }
    return grouped;
  }

  /// Export all bookmarks as JSON
  static String exportAllBookmarks() {
    final bookmarks = getAllBookmarks();
    return jsonEncode({
      'version': exportVersion,
      'app': exportApp,
      'exportedAt': DateTime.now().toIso8601String(),
      'count': bookmarks.length,
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
    });
  }

  /// Import bookmarks from JSON
  static Future<int> importBookmarks(String jsonString) async {
    if (utf8.encode(jsonString).length > maxImportJsonBytes) {
      throw const FormatException('Bookmark export exceeds 8 MiB.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException catch (error) {
      throw FormatException('Bookmark JSON is invalid: ${error.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('Bookmark export must be a JSON object.');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['version'] != exportVersion) {
      throw FormatException(
        'Unsupported bookmark export version: ${data['version']}',
      );
    }
    if (data['app'] != exportApp) {
      throw const FormatException('Bookmark export source is invalid.');
    }
    final exportedAt = data['exportedAt'];
    if (exportedAt is! String || DateTime.tryParse(exportedAt) == null) {
      throw const FormatException('Bookmark export time is invalid.');
    }
    final rawBookmarks = data['bookmarks'];
    if (rawBookmarks is! List) {
      throw const FormatException('Bookmark export is missing bookmarks.');
    }
    if (rawBookmarks.length > maxImportEntries) {
      throw const FormatException(
        'Bookmark export contains more than 10000 entries.',
      );
    }
    final declaredCount = data['count'];
    if (declaredCount is! int || declaredCount != rawBookmarks.length) {
      throw FormatException(
        'Bookmark count mismatch: declared $declaredCount, '
        'actual ${rawBookmarks.length}.',
      );
    }

    final countsByBvid = <String, int>{};
    for (final bookmark in box.values) {
      countsByBvid.update(
        bookmark.bvid,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final pending = <String, VideoBookmark>{};
    for (final (index, rawBookmark) in rawBookmarks.indexed) {
      if (rawBookmark is! Map) {
        throw FormatException('Bookmark entry ${index + 1} must be an object.');
      }
      final VideoBookmark bookmark;
      try {
        bookmark = _normalizeBookmark(
          VideoBookmark.fromJson(Map<String, dynamic>.from(rawBookmark)),
        );
      } on FormatException catch (error) {
        throw FormatException(
          'Bookmark entry ${index + 1} is invalid: ${error.message}',
        );
      } catch (_) {
        throw FormatException('Bookmark entry ${index + 1} is invalid.');
      }
      if (!_isValidBvid(bookmark.bvid)) {
        throw FormatException(
          'Bookmark entry ${index + 1} has an invalid bvid.',
        );
      }
      if (box.containsKey(bookmark.id) || pending.containsKey(bookmark.id)) {
        continue;
      }

      final count = countsByBvid[bookmark.bvid] ?? 0;
      if (count < maxBookmarksPerVideo) {
        pending[bookmark.id] = bookmark;
        countsByBvid[bookmark.bvid] = count + 1;
      }
    }

    if (pending.isNotEmpty) {
      await box.putAll(pending);
    }
    return pending.length;
  }

  static void _validateNewBookmarkMetadata({
    required String bvid,
    required String videoTitle,
    required int? authorMid,
  }) {
    if (bvid.length > VideoBookmark.maxBvidLength || !_isValidBvid(bvid)) {
      throw const FormatException('bvid is invalid.');
    }
    if (videoTitle.isEmpty ||
        videoTitle.length > VideoBookmark.maxVideoTitleLength) {
      throw const FormatException('videoTitle is invalid.');
    }
    if (authorMid != null && authorMid <= 0) {
      throw const FormatException('authorMid must be a positive integer.');
    }
  }

  static bool _isValidBvid(String bvid) {
    if (!IdUtils.bvRegexExact.hasMatch(bvid)) return false;
    try {
      IdUtils.bv2av(bvid);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Clear all bookmarks
  static Future<void> clearAllBookmarks() async {
    await box.clear();
  }

  /// Get bookmarks sorted by different criteria
  static List<VideoBookmark> getBookmarksSorted({
    required SortType sortType,
    String? bvidFilter,
    int? authorMidFilter,
    String? searchQuery,
  }) {
    var bookmarks = box.values.toList();

    // Apply filters
    if (bvidFilter != null) {
      bookmarks = bookmarks.where((b) => b.bvid == bvidFilter).toList();
    }
    if (authorMidFilter != null) {
      bookmarks = bookmarks
          .where((b) => b.authorMid == authorMidFilter)
          .toList();
    }
    final normalizedQuery = searchQuery?.trim().toLowerCase();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      bookmarks = bookmarks.where((bookmark) {
        return bookmark.name.toLowerCase().contains(normalizedQuery) ||
            (bookmark.note?.toLowerCase().contains(normalizedQuery) ?? false);
      }).toList();
    }

    // Apply sorting
    switch (sortType) {
      case SortType.mostRecent:
        bookmarks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortType.videoName:
        bookmarks.sort((a, b) {
          final cmp = a.videoTitle.compareTo(b.videoTitle);
          if (cmp != 0) return cmp;
          return a.timestampSeconds.compareTo(b.timestampSeconds);
        });
        break;
      case SortType.timestamp:
        bookmarks.sort(
          (a, b) => a.timestampSeconds.compareTo(b.timestampSeconds),
        );
        break;
    }

    return bookmarks;
  }

  static List<int> getAuthorMids() {
    return box.values
        .map((bookmark) => bookmark.authorMid)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
  }

  static VideoBookmark _normalizeBookmark(VideoBookmark bookmark) {
    final trimmedName = bookmark.name.trim();
    final trimmedNote = bookmark.note?.trim();
    final safeTimestamp = bookmark.timestampSeconds < 0
        ? 0
        : bookmark.timestampSeconds;
    return VideoBookmark(
      id: bookmark.id,
      bvid: bookmark.bvid,
      videoTitle: bookmark.videoTitle,
      authorMid: bookmark.authorMid,
      timestampSeconds: safeTimestamp,
      name: _truncate(
        trimmedName.isEmpty
            ? '标记 @ ${VideoBookmark.formatTimestamp(safeTimestamp)}'
            : trimmedName,
        VideoBookmark.maxNameLength,
      ),
      note: trimmedNote == null || trimmedNote.isEmpty
          ? null
          : _truncate(trimmedNote, VideoBookmark.maxNoteLength),
      createdAt: bookmark.createdAt,
    );
  }

  static String _truncate(String value, int maxLength) =>
      value.length <= maxLength ? value : value.substring(0, maxLength);
}

enum SortType {
  mostRecent,
  videoName,
  timestamp,
}
