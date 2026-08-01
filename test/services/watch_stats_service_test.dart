import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/watch_stats_session.dart';
import 'package:pili_plus/services/watch_stats_service.dart';

void main() {
  group('WatchStatsSession', () {
    test('uses the dedicated Hive type id and round-trips JSON', () {
      final session = _session(
        bvid: 'BV1test',
        title: 'Test Video',
        authorName: 'Test Author',
        authorMid: 123,
        watchedSeconds: 90,
        at: DateTime(2026, 7, 31, 12),
      );

      expect(WatchStatsSessionAdapter().typeId, 102);
      final restored = WatchStatsSession.fromJson(session.toJson());
      expect(restored.bvid, session.bvid);
      expect(restored.authorMid, session.authorMid);
      expect(restored.watchedSeconds, session.watchedSeconds);
      expect(restored.date, '2026-07-31');
    });
  });

  group('WatchSessionTracker', () {
    const metadata = WatchSessionMetadata(
      bvid: 'BV1delta',
      title: 'Position Delta',
      authorName: 'UP',
      authorMid: 42,
    );

    test('counts position deltas but ignores pause, buffering and seek', () {
      final tracker = WatchSessionTracker(
        persistenceChunk: const Duration(hours: 1),
      );
      final start = DateTime(2026, 7, 31, 12);
      tracker
        ..begin(metadata: metadata, position: Duration.zero, at: start)
        ..onPosition(
          position: const Duration(seconds: 1),
          at: start.add(const Duration(seconds: 1)),
          isPlaying: true,
          isBuffering: false,
          isSeeking: false,
          playbackSpeed: 1,
        )
        ..onPosition(
          position: const Duration(seconds: 1),
          at: start.add(const Duration(seconds: 8)),
          isPlaying: false,
          isBuffering: false,
          isSeeking: false,
          playbackSpeed: 1,
        )
        ..onPosition(
          position: const Duration(seconds: 2),
          at: start.add(const Duration(seconds: 9)),
          isPlaying: true,
          isBuffering: true,
          isSeeking: false,
          playbackSpeed: 1,
        )
        ..markSeek(
          position: const Duration(seconds: 100),
          at: start.add(const Duration(seconds: 10)),
        )
        ..onPosition(
          position: const Duration(seconds: 101),
          at: start.add(const Duration(seconds: 11)),
          isPlaying: true,
          isBuffering: false,
          isSeeking: false,
          playbackSpeed: 1,
        );

      final completed = tracker.finish(start.add(const Duration(seconds: 12)));
      expect(completed, hasLength(1));
      expect(completed.single.watchedSeconds, 2);
    });

    test('five minutes of inactivity ends the previous session', () {
      final tracker = WatchSessionTracker(
        persistenceChunk: const Duration(hours: 1),
      );
      final start = DateTime(2026, 7, 31, 12);
      tracker
        ..begin(metadata: metadata, position: Duration.zero, at: start)
        ..onPosition(
          position: const Duration(seconds: 10),
          at: start.add(const Duration(seconds: 10)),
          isPlaying: true,
          isBuffering: false,
          isSeeking: false,
          playbackSpeed: 1,
        );

      final ended = tracker.onPosition(
        position: const Duration(seconds: 20),
        at: start.add(const Duration(minutes: 5, seconds: 11)),
        isPlaying: true,
        isBuffering: false,
        isSeeking: false,
        playbackSpeed: 1,
      );
      expect(ended, hasLength(1));
      expect(ended.single.watchedSeconds, 10);

      tracker.onPosition(
        position: const Duration(seconds: 21),
        at: start.add(const Duration(minutes: 5, seconds: 12)),
        isPlaying: true,
        isBuffering: false,
        isSeeking: false,
        playbackSpeed: 1,
      );
      expect(
        tracker
            .finish(start.add(const Duration(minutes: 5, seconds: 13)))
            .single
            .watchedSeconds,
        1,
      );
    });
  });

  group('WatchStatsAggregator', () {
    final now = DateTime(2026, 7, 31, 12);
    final sessions = [
      _session(
        bvid: 'BV1a',
        title: 'A',
        authorName: '旧名称',
        authorMid: 10,
        watchedSeconds: 60,
        at: DateTime(2026, 7, 31, 10),
      ),
      _session(
        bvid: 'BV1a',
        title: 'A 新标题',
        authorName: '新名称',
        authorMid: 10,
        watchedSeconds: 120,
        at: DateTime(2026, 7, 30, 10),
      ),
      _session(
        bvid: 'BV1b',
        title: 'B',
        authorName: '另一位',
        authorMid: 20,
        watchedSeconds: 30,
        at: DateTime(2026, 7, 29, 10),
      ),
      _session(
        bvid: 'BV1old',
        title: '更早的视频',
        authorName: '另一位',
        authorMid: 20,
        watchedSeconds: 300,
        at: DateTime(2026, 7, 10, 10),
      ),
    ];

    test(
      'uses local calendar boundaries and stable creator/video identities',
      () {
        final range = WatchStatsDateRange.forPeriod(
          WatchStatsPeriod.week,
          now: now,
        );
        final stats = WatchStatsAggregator.aggregate(
          period: WatchStatsPeriod.week,
          range: range,
          sessions: sessions,
        );

        expect(stats.totalWatchTimeSeconds, 210);
        expect(stats.videosWatched, 2);
        expect(stats.uniqueCreatorCount, 2);
        expect(stats.dailyWatchTime, hasLength(7));
        expect(stats.topCreators.first.authorMid, 10);
        expect(stats.topCreators.first.authorName, '新名称');
        expect(stats.topCreators.first.watchedSeconds, 180);
        expect(stats.longestVideos.first.bvid, 'BV1a');
        expect(stats.longestVideos.first.title, 'A 新标题');
      },
    );

    test(
      'month includes earlier retained sessions and all range is bounded',
      () {
        final month = WatchStatsDateRange.forPeriod(
          WatchStatsPeriod.month,
          now: now,
        );
        final monthStats = WatchStatsAggregator.aggregate(
          period: WatchStatsPeriod.month,
          range: month,
          sessions: sessions,
        );
        expect(monthStats.totalWatchTimeSeconds, 510);
        expect(monthStats.dailyWatchTime, hasLength(30));

        final all = WatchStatsDateRange.forPeriod(
          WatchStatsPeriod.all,
          now: now,
          earliestSession: DateTime(2025),
        );
        expect(all.periodDays, 90);
        expect(all.chartDays, 90);
      },
    );
  });

  test('JSON and CSV exports preserve metadata and escape cells', () {
    final session = _session(
      bvid: 'BV1csv',
      title: '标题,带逗号',
      authorName: '名字"带引号',
      authorMid: 99,
      watchedSeconds: 15,
      at: DateTime(2026, 7, 31, 12),
    );
    final json = WatchStatsService.encodeJson(
      [session],
      exportedAt: DateTime(2026, 7, 31, 13),
    );
    final csv = WatchStatsService.encodeCsv([session]);

    expect(json, contains('"authorMid": 99'));
    expect(json, contains('"localOnly": true'));
    expect(csv, contains('"标题,带逗号"'));
    expect(csv, contains('"名字""带引号"'));
  });
}

WatchStatsSession _session({
  required String bvid,
  required String title,
  required String authorName,
  required int authorMid,
  required int watchedSeconds,
  required DateTime at,
}) {
  return WatchStatsSession(
    bvid: bvid,
    title: title,
    authorName: authorName,
    authorMid: authorMid,
    watchedSeconds: watchedSeconds,
    timestamp: at.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
    date:
        '${at.year.toString().padLeft(4, '0')}-'
        '${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')}',
  );
}
