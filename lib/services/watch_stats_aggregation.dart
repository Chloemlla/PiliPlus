import 'package:intl/intl.dart';
import 'package:pili_plus/models/watch_stats_session.dart';

enum WatchStatsPeriod { week, month, all }

final class WatchStatsDateRange {
  const WatchStatsDateRange({
    required this.start,
    required this.endExclusive,
    required this.chartDays,
  });

  final DateTime start;
  final DateTime endExclusive;
  final int chartDays;

  int get periodDays =>
      endExclusive.difference(start).inDays.clamp(1, 90).toInt();

  bool contains(WatchStatsSession session) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      session.timestamp * Duration.millisecondsPerSecond,
    );
    return !timestamp.isBefore(start) && timestamp.isBefore(endExclusive);
  }

  WatchStatsDateRange previous() {
    final length = endExclusive.difference(start);
    return WatchStatsDateRange(
      start: start.subtract(length),
      endExclusive: start,
      chartDays: chartDays,
    );
  }

  static WatchStatsDateRange forPeriod(
    WatchStatsPeriod period, {
    required DateTime now,
    DateTime? earliestSession,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final endExclusive = today.add(const Duration(days: 1));
    return switch (period) {
      WatchStatsPeriod.week => WatchStatsDateRange(
        start: today.subtract(const Duration(days: 6)),
        endExclusive: endExclusive,
        chartDays: 7,
      ),
      WatchStatsPeriod.month => WatchStatsDateRange(
        start: today.subtract(const Duration(days: 29)),
        endExclusive: endExclusive,
        chartDays: 30,
      ),
      WatchStatsPeriod.all => () {
        final earliest = earliestSession == null
            ? today
            : DateTime(
                earliestSession.year,
                earliestSession.month,
                earliestSession.day,
              );
        final retainedStart = today.subtract(const Duration(days: 89));
        final start = earliest.isBefore(retainedStart)
            ? retainedStart
            : earliest;
        return WatchStatsDateRange(
          start: start,
          endExclusive: endExclusive,
          chartDays: endExclusive.difference(start).inDays.clamp(1, 90).toInt(),
        );
      }(),
    };
  }
}

final class WatchStatsDailyPoint {
  const WatchStatsDailyPoint({
    required this.date,
    required this.watchedSeconds,
  });

  final DateTime date;
  final int watchedSeconds;

  String get storageKey => DateFormat('yyyy-MM-dd').format(date);
}

final class WatchStatsCreatorRank {
  const WatchStatsCreatorRank({
    required this.authorMid,
    required this.authorName,
    required this.watchedSeconds,
  });

  final int authorMid;
  final String authorName;
  final int watchedSeconds;
}

final class WatchStatsVideoRank {
  const WatchStatsVideoRank({
    required this.bvid,
    required this.title,
    required this.authorName,
    required this.watchedSeconds,
  });

  final String bvid;
  final String title;
  final String authorName;
  final int watchedSeconds;
}

final class WatchStatsData {
  const WatchStatsData({
    required this.period,
    required this.totalWatchTimeSeconds,
    required this.videosWatched,
    required this.sessionCount,
    required this.uniqueCreatorCount,
    required this.dailyWatchTime,
    required this.topCreators,
    required this.longestVideos,
    required this.periodDays,
    required this.previousPeriodWatchTimeSeconds,
  });

  final WatchStatsPeriod period;
  final int totalWatchTimeSeconds;
  final int videosWatched;
  final int sessionCount;
  final int uniqueCreatorCount;
  final List<WatchStatsDailyPoint> dailyWatchTime;
  final List<WatchStatsCreatorRank> topCreators;
  final List<WatchStatsVideoRank> longestVideos;
  final int periodDays;
  final int previousPeriodWatchTimeSeconds;

  String get formattedWatchTime => formatWatchDuration(totalWatchTimeSeconds);

  double get dailyAverageSeconds => totalWatchTimeSeconds / periodDays;

  String get formattedDailyAverage => formatWatchDuration(
    dailyAverageSeconds.round(),
  );

  double? get comparisonToPrevious {
    if (previousPeriodWatchTimeSeconds <= 0) return null;
    return (totalWatchTimeSeconds - previousPeriodWatchTimeSeconds) /
        previousPeriodWatchTimeSeconds;
  }

  static String formatWatchDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    const secondsPerHour = Duration.secondsPerMinute * Duration.minutesPerHour;
    final hours = safeSeconds ~/ secondsPerHour;
    final minutes = (safeSeconds % secondsPerHour) ~/ Duration.secondsPerMinute;
    if (hours > 0) {
      return '$hours小时$minutes分钟';
    }
    if (minutes > 0) {
      return '$minutes分钟';
    }
    return '${safeSeconds % Duration.secondsPerMinute}秒';
  }
}

abstract final class WatchStatsAggregator {
  static WatchStatsData aggregate({
    required WatchStatsPeriod period,
    required WatchStatsDateRange range,
    required List<WatchStatsSession> sessions,
    int previousPeriodWatchTimeSeconds = 0,
  }) {
    final selected = sessions.where(range.contains).toList();
    final dailyTotals = <String, int>{};
    final creators = <String, _CreatorAccumulator>{};
    final videos = <String, _VideoAccumulator>{};

    var totalWatchTime = 0;
    for (final session in selected) {
      if (session.watchedSeconds <= 0 || session.bvid.isEmpty) continue;
      totalWatchTime += session.watchedSeconds;
      dailyTotals.update(
        session.date,
        (value) => value + session.watchedSeconds,
        ifAbsent: () => session.watchedSeconds,
      );

      final normalizedName = session.authorName.trim().isEmpty
          ? '未知UP主'
          : session.authorName.trim();
      final creatorKey = session.authorMid > 0
          ? 'mid:${session.authorMid}'
          : 'name:$normalizedName';
      creators.update(
        creatorKey,
        (value) => value
          ..watchedSeconds += session.watchedSeconds
          ..authorName = normalizedName,
        ifAbsent: () => _CreatorAccumulator(
          authorMid: session.authorMid,
          authorName: normalizedName,
          watchedSeconds: session.watchedSeconds,
        ),
      );

      final normalizedTitle = session.title.trim().isEmpty
          ? session.bvid
          : session.title.trim();
      videos.update(
        session.bvid,
        (value) => value
          ..watchedSeconds += session.watchedSeconds
          ..title = normalizedTitle
          ..authorName = normalizedName,
        ifAbsent: () => _VideoAccumulator(
          bvid: session.bvid,
          title: normalizedTitle,
          authorName: normalizedName,
          watchedSeconds: session.watchedSeconds,
        ),
      );
    }

    final chartStart = range.endExclusive.subtract(
      Duration(days: range.chartDays),
    );
    final dailyPoints = List.generate(range.chartDays, (index) {
      final date = chartStart.add(Duration(days: index));
      final key = DateFormat('yyyy-MM-dd').format(date);
      return WatchStatsDailyPoint(
        date: date,
        watchedSeconds: dailyTotals[key] ?? 0,
      );
    });

    final topCreators =
        creators.values
            .map(
              (creator) => WatchStatsCreatorRank(
                authorMid: creator.authorMid,
                authorName: creator.authorName,
                watchedSeconds: creator.watchedSeconds,
              ),
            )
            .toList()
          ..sort((a, b) => b.watchedSeconds.compareTo(a.watchedSeconds));

    final longestVideos =
        videos.values
            .map(
              (video) => WatchStatsVideoRank(
                bvid: video.bvid,
                title: video.title,
                authorName: video.authorName,
                watchedSeconds: video.watchedSeconds,
              ),
            )
            .toList()
          ..sort((a, b) => b.watchedSeconds.compareTo(a.watchedSeconds));

    return WatchStatsData(
      period: period,
      totalWatchTimeSeconds: totalWatchTime,
      videosWatched: videos.length,
      sessionCount: selected.length,
      uniqueCreatorCount: creators.length,
      dailyWatchTime: dailyPoints,
      topCreators: topCreators.take(5).toList(),
      longestVideos: longestVideos.take(5).toList(),
      periodDays: range.periodDays,
      previousPeriodWatchTimeSeconds: previousPeriodWatchTimeSeconds,
    );
  }
}

final class _CreatorAccumulator {
  _CreatorAccumulator({
    required this.authorMid,
    required this.authorName,
    required this.watchedSeconds,
  });

  final int authorMid;
  String authorName;
  int watchedSeconds;
}

final class _VideoAccumulator {
  _VideoAccumulator({
    required this.bvid,
    required this.title,
    required this.authorName,
    required this.watchedSeconds,
  });

  final String bvid;
  String title;
  String authorName;
  int watchedSeconds;
}
