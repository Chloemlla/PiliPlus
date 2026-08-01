import 'dart:convert';
import 'dart:io';

import 'package:hive_ce/hive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pili_plus/models/watch_stats_session.dart';
import 'package:pili_plus/services/watch_session_tracker.dart';
import 'package:pili_plus/services/watch_stats_aggregation.dart';

export 'package:pili_plus/services/watch_session_tracker.dart';
export 'package:pili_plus/services/watch_stats_aggregation.dart';

typedef WatchStatsClock = DateTime Function();

class WatchStatsService {
  WatchStatsService._({WatchStatsClock? clock})
    : _clock = clock ?? DateTime.now;

  static final WatchStatsService instance = WatchStatsService._();

  static const String boxName = 'watchStatsSessions';
  static const int adapterTypeId = 102;
  static const int maxRetentionDays = 90;

  final WatchStatsClock _clock;
  Box<WatchStatsSession>? _box;
  Future<void>? _initializing;

  bool get isInitialized => _box?.isOpen ?? false;

  Box<WatchStatsSession> get box {
    final current = _box;
    if (current == null || !current.isOpen) {
      throw StateError('WatchStatsService is not initialized.');
    }
    return current;
  }

  Future<void> init() {
    if (isInitialized) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      if (!Hive.isAdapterRegistered(adapterTypeId)) {
        Hive.registerAdapter(WatchStatsSessionAdapter());
      }
      _box = await Hive.openBox<WatchStatsSession>(boxName);
      await pruneOldSessions();
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> recordPendingSession(PendingWatchSession pending) {
    return recordSession(
      bvid: pending.metadata.bvid,
      title: pending.metadata.title,
      authorName: pending.metadata.authorName,
      authorMid: pending.metadata.authorMid,
      watchedSeconds: pending.watchedSeconds,
      endedAt: pending.endedAt,
    );
  }

  Future<void> recordSession({
    required String bvid,
    required String title,
    required String authorName,
    required int authorMid,
    required int watchedSeconds,
    DateTime? endedAt,
  }) async {
    if (bvid.isEmpty || watchedSeconds <= 0) return;
    await init();

    final end = endedAt ?? _clock();
    await box.add(
      WatchStatsSession(
        bvid: bvid,
        title: title.trim(),
        authorName: authorName.trim(),
        authorMid: authorMid,
        watchedSeconds: watchedSeconds,
        timestamp: end.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
        date: DateFormat('yyyy-MM-dd').format(end),
      ),
    );
  }

  List<WatchStatsSession> get allSessions {
    if (!isInitialized) return const [];
    final sessions = box.values.toList();
    sessions.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sessions;
  }

  List<WatchStatsSession> getSessionsInRange(
    DateTime start,
    DateTime endExclusive,
  ) {
    if (!isInitialized) return const [];
    final startTimestamp =
        start.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final endTimestamp =
        endExclusive.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    return box.values
        .where(
          (session) =>
              session.timestamp >= startTimestamp &&
              session.timestamp < endTimestamp,
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  WatchStatsData getStats(
    WatchStatsPeriod period, {
    DateTime? now,
  }) {
    final currentTime = now ?? _clock();
    final sessions = allSessions;
    final earliestSession = sessions.isEmpty
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            sessions.first.timestamp * Duration.millisecondsPerSecond,
          );
    final range = WatchStatsDateRange.forPeriod(
      period,
      now: currentTime,
      earliestSession: earliestSession,
    );
    final previousWatchTime = period == WatchStatsPeriod.all
        ? 0
        : _totalWatchTime(sessions.where(range.previous().contains));
    return WatchStatsAggregator.aggregate(
      period: period,
      range: range,
      sessions: sessions,
      previousPeriodWatchTimeSeconds: previousWatchTime,
    );
  }

  Future<void> pruneOldSessions({DateTime? now}) async {
    if (!isInitialized) return;
    final current = now ?? _clock();
    final today = DateTime(current.year, current.month, current.day);
    final cutoff = today.subtract(
      const Duration(days: maxRetentionDays - 1),
    );
    final cutoffTimestamp =
        cutoff.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final keysToDelete = box.keys.where((key) {
      final session = box.get(key);
      return session != null && session.timestamp < cutoffTimestamp;
    }).toList();
    if (keysToDelete.isNotEmpty) {
      await box.deleteAll(keysToDelete);
    }
  }

  Future<void> clearAll() async {
    await init();
    await box.clear();
  }

  Future<String> exportAsJson() async {
    await init();
    return encodeJson(allSessions, exportedAt: _clock());
  }

  Future<String> exportAsCsv() async {
    await init();
    return encodeCsv(allSessions);
  }

  static String encodeJson(
    Iterable<WatchStatsSession> sessions, {
    required DateTime exportedAt,
  }) {
    final values = sessions.map((session) => session.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'exportedAt': exportedAt.toIso8601String(),
      'localOnly': true,
      'totalSessions': values.length,
      'sessions': values,
    });
  }

  static String encodeCsv(Iterable<WatchStatsSession> sessions) {
    final buffer = StringBuffer(
      'bvid,title,authorName,authorMid,watchedSeconds,timestamp,date\r\n',
    );
    for (final session in sessions) {
      buffer
        ..write(_escapeCsv(session.bvid))
        ..write(',')
        ..write(_escapeCsv(session.title))
        ..write(',')
        ..write(_escapeCsv(session.authorName))
        ..write(',')
        ..write(session.authorMid)
        ..write(',')
        ..write(session.watchedSeconds)
        ..write(',')
        ..write(session.timestamp)
        ..write(',')
        ..write(_escapeCsv(session.date))
        ..write('\r\n');
    }
    return buffer.toString();
  }

  Future<File> saveExport(String filename, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(path.join(directory.path, filename));
    await file.writeAsString(content, flush: true);
    return file;
  }

  Future<void> close() async {
    await _box?.close();
    _box = null;
    _initializing = null;
  }

  static int _totalWatchTime(Iterable<WatchStatsSession> sessions) =>
      sessions.fold(0, (total, session) => total + session.watchedSeconds);

  static String _escapeCsv(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
