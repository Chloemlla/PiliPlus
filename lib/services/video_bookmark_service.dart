import 'dart:convert';
import 'package:pili_plus/models/video_bookmark.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:hive_ce/hive.dart';

class VideoBookmarkService {
  static const String boxName = 'videoBookmarks';
  static const int maxBookmarksPerVideo = 200;
  static const String _bookmarkIdKey = 'bookmarkIdCounter';

  static Box<VideoBookmark>? _box;

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(VideoBookmarkAdapter());
    }
    _box = await Hive.openBox<VideoBookmark>(boxName);
  }

  static Box<VideoBookmark> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('VideoBookmarkService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// Generate unique bookmark ID
  static String _generateId() {
    final counter = box.get(_bookmarkIdKey, defaultValue: 0) as int;
    box.put(_bookmarkIdKey, counter + 1);
    return 'bm_${DateTime.now().millisecondsSinceEpoch}_$counter';
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
    if (!canAddBookmark(bvid)) {
      return null;
    }

    final now = DateTime.now();
    final defaultName = name ?? '标记 @ ${_formatTimestamp(timestampSeconds)}';

    final bookmark = VideoBookmark(
      id: _generateId(),
      bvid: bvid,
      videoTitle: videoTitle,
      authorMid: authorMid,
      timestampSeconds: timestampSeconds,
      name: defaultName,
      note: note,
      createdAt: now,
    );

    await box.put(bookmark.id, bookmark);
    return bookmark;
  }

  /// Update a bookmark's name or note
  static Future<void> updateBookmark(VideoBookmark bookmark) async {
    await box.put(bookmark.id, bookmark);
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
    final lowerQuery = query.toLowerCase();
    return box.values.where((b) {
      return b.name.toLowerCase().contains(lowerQuery) ||
          (b.note?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      'version': 1,
      'app': 'PiliPlus',
      'exportedAt': DateTime.now().toIso8601String(),
      'count': bookmarks.length,
      'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
    });
  }

  /// Import bookmarks from JSON
  static Future<int> importBookmarks(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final bookmarks = (data['bookmarks'] as List)
        .map((j) => VideoBookmark.fromJson(j as Map<String, dynamic>))
        .toList();

    int importedCount = 0;
    for (final bookmark in bookmarks) {
      // Skip duplicates by ID
      if (!box.containsKey(bookmark.id)) {
        await box.put(bookmark.id, bookmark);
        importedCount++;
      }
    }
    return importedCount;
  }

  /// Clear all bookmarks
  static Future<void> clearAllBookmarks() async {
    await box.clear();
  }

  static String _formatTimestamp(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Get bookmarks sorted by different criteria
  static List<VideoBookmark> getBookmarksSorted({
    required SortType sortType,
    String? bvidFilter,
    int? authorMidFilter,
  }) {
    var bookmarks = box.values.toList();

    // Apply filters
    if (bvidFilter != null) {
      bookmarks = bookmarks.where((b) => b.bvid == bvidFilter).toList();
    }
    if (authorMidFilter != null) {
      bookmarks = bookmarks.where((b) => b.authorMid == authorMidFilter).toList();
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
        bookmarks.sort((a, b) => a.timestampSeconds.compareTo(b.timestampSeconds));
        break;
    }

    return bookmarks;
  }
}

enum SortType {
  mostRecent,
  videoName,
  timestamp,
}
