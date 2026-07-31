import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pili_plus/models/watch_stats_session.dart';
import 'package:pili_plus/utils/path_utils.dart';
import 'package:pili_plus/utils/storage.dart';

class WatchStatsService {
  WatchStatsService._();

  static final WatchStatsService instance = WatchStatsService._();

  static const String boxName = 'watchStatsSessions';
  static const int maxRetentionDays = 90;

  Box<WatchStatsSession>? _box;
  Box<WatchStatsSession> get box {
    if (_box == null) {
      throw StateError('WatchStatsService not initialized. Call init() first.');
    }
    return _box!;
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the service and open Hive box
  Future<void> init() async {
    if (_isInitialized) return;

    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(WatchStatsSessionAdapter());
    }

    _box = await Hive.openBox<WatchStatsSession>(boxName);
    _isInitialized = true;

    // Prune old entries on init
    await pruneOldSessions();
  }

  /// Record a watch session
  Future<void> recordSession({
    required String bvid,
    required String title,
    required String authorName,
    required int authorMid,
    required int watchedSeconds,
  }) async {
    if (!_isInitialized) return;

    final now = DateTime.now();
    final session = WatchStatsSession(
      bvid: bvid,
      title: title,
      authorName: authorName,
      authorMid: authorMid,
      watchedSeconds: watchedSeconds,
      timestamp: now.millisecondsSinceEpoch ~/ 1000,
      date: DateFormat('yyyy-MM-dd').format(now),
    );

    await box.add(session);
  }

  /// Get all sessions within a date range
  List<WatchStatsSession> getSessionsInRange(DateTime start, DateTime end) {
    if (!_isInitialized) return [];

    final startTs = start.millisecondsSinceEpoch ~/ 1000;
    final endTs = end.millisecondsSinceEpoch ~/ 1000;

    return box.values
        .where((s) => s.timestamp >= startTs && s.timestamp <= endTs)
        .toList();
  }

  /// Get sessions for the last N days
  List<WatchStatsSession> getSessionsForDays(int days) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    return getSessionsInRange(start, now);
  }

  /// Get total watch time in seconds for a list of sessions
  int getTotalWatchTime(List<WatchStatsSession> sessions) {
    return sessions.fold(0, (sum, s) => sum + s.watchedSeconds);
  }

  /// Get unique video count
  int getUniqueVideoCount(List<WatchStatsSession> sessions) {
    return sessions.map((s) => s.bvid).toSet().length;
  }

  /// Get daily watch time breakdown
  Map<String, int> getDailyWatchTime(List<WatchStatsSession> sessions) {
    return sessions.groupFoldBy(
      (s) => s.date,
      (sum, s) => sum + s.watchedSeconds,
    );
  }

  /// Get top N creators by watch time
  List<MapEntry<String, int>> getTopCreators(
    List<WatchStatsSession> sessions, {
    int limit = 5,
  }) {
    final creatorTime = sessions.groupFoldBy(
      (s) => s.authorName,
      (sum, s) => sum + s.watchedSeconds,
    );

    final sorted = creatorTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).toList();
  }

  /// Get top N longest videos
  List<MapEntry<String, int>> getLongestVideos(
    List<WatchStatsSession> sessions, {
    int limit = 5,
  }) {
    // Group by bvid and sum watch time
    final videoTime = <String, int>{};
    final videoTitles = <String, String>{};

    for (final session in sessions) {
      videoTime[session.bvid] = (videoTime[session.bvid] ?? 0) + session.watchedSeconds;
      videoTitles[session.bvid] = session.title;
    }

    final sorted = videoTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).toList();
  }

  /// Prune sessions older than maxRetentionDays
  Future<void> pruneOldSessions() async {
    if (!_isInitialized) return;

    final cutoff = DateTime.now()
        .subtract(const Duration(days: maxRetentionDays))
        .millisecondsSinceEpoch ~/ 1000;

    final keysToDelete = box.keys.where((key) {
      final session = box.get(key);
      return session != null && session.timestamp < cutoff;
    }).toList();

    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
  }

  /// Clear all watch statistics
  Future<void> clearAll() async {
    if (!_isInitialized) return;
    await box.clear();
  }

  /// Export statistics as JSON
  Future<String> exportAsJson() async {
    if (!_isInitialized) return '{}';

    final sessions = box.values.map((s) => s.toJson()).toList();
    final stats = {
      'exportDate': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      'totalSessions': sessions.length,
      'sessions': sessions,
    };

    return const JsonEncoder.withIndent('  ').convert(stats);
  }

  /// Export statistics as CSV
  Future<String> exportAsCsv() async {
    if (!_isInitialized) return '';

    final buffer = StringBuffer();
    buffer.writeln('bvid,title,authorName,authorMid,watchedSeconds,timestamp,date');

    for (final session in box.values) {
      buffer.writeln(
        '${_escapeCsv(session.bvid)},'
        '${_escapeCsv(session.title)},'
        '${_escapeCsv(session.authorName)},'
        '${session.authorMid},'
        '${session.watchedSeconds},'
        '${session.timestamp},'
        '${session.date}',
      );
    }

    return buffer.toString();
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Get export file path
  Future<String> getExportPath(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, filename);
  }

  /// Save export to file
  Future<File> saveExport(String filename, String content) async {
    final filePath = await getExportPath(filename);
    final file = File(filePath);
    await file.writeAsString(content);
    return file;
  }

  /// Close the service
  Future<void> close() async {
    await _box?.close();
    _isInitialized = false;
  }
}

/// Aggregated watch statistics data
class WatchStatsData {
  final int totalWatchTimeSeconds;
  final int videosWatched;
  final int uniqueVideoCount;
  final int uniqueCreatorCount;
  final Map<String, int> dailyWatchTime;
  final List<MapEntry<String, int>> topCreators;
  final List<MapEntry<String, int>> longestVideos;
  final int periodDays;

  WatchStatsData({
    required this.totalWatchTimeSeconds,
    required this.videosWatched,
    required this.uniqueVideoCount,
    required this.uniqueCreatorCount,
    required this.dailyWatchTime,
    required this.topCreators,
    required this.longestVideos,
    required this.periodDays,
  });

  String get formattedWatchTime {
    final hours = totalWatchTimeSeconds ~/ 3600;
    final minutes = (totalWatchTimeSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  double get dailyAverageSeconds {
    if (periodDays <= 0) return 0;
    return totalWatchTimeSeconds / periodDays;
  }

  String get formattedDailyAverage {
    final hours = dailyAverageSeconds ~/ 3600;
    final minutes = ((dailyAverageSeconds % 3600) ~/ 60).round();
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
