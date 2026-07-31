import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/watch_stats_session.dart';
import 'package:pili_plus/services/watch_stats_service.dart';

void main() {
  group('WatchStatsSession', () {
    test('creates from constructor', () {
      final session = WatchStatsSession(
        bvid: 'BV1234567890',
        title: 'Test Video',
        authorName: 'Test Author',
        authorMid: 12345678,
        watchedSeconds: 3600,
        timestamp: 1234567890,
        date: '2024-01-01',
      );

      expect(session.bvid, 'BV1234567890');
      expect(session.title, 'Test Video');
      expect(session.authorName, 'Test Author');
      expect(session.authorMid, 12345678);
      expect(session.watchedSeconds, 3600);
      expect(session.timestamp, 1234567890);
      expect(session.date, '2024-01-01');
    });

    test('serializes to JSON', () {
      final session = WatchStatsSession(
        bvid: 'BV1234567890',
        title: 'Test Video',
        authorName: 'Test Author',
        authorMid: 12345678,
        watchedSeconds: 3600,
        timestamp: 1234567890,
        date: '2024-01-01',
      );

      final json = session.toJson();
      expect(json['bvid'], 'BV1234567890');
      expect(json['title'], 'Test Video');
    });

    test('deserializes from JSON', () {
      final json = {
        'bvid': 'BV1234567890',
        'title': 'Test Video',
        'authorName': 'Test Author',
        'authorMid': 12345678,
        'watchedSeconds': 3600,
        'timestamp': 1234567890,
        'date': '2024-01-01',
      };

      final session = WatchStatsSession.fromJson(json);
      expect(session.bvid, 'BV1234567890');
      expect(session.title, 'Test Video');
      expect(session.watchedSeconds, 3600);
    });
  });

  group('WatchStatsData', () {
    test('formats watch time correctly', () {
      final stats = WatchStatsData(
        totalWatchTimeSeconds: 3660, // 1h 1m
        videosWatched: 5,
        uniqueVideoCount: 3,
        uniqueCreatorCount: 2,
        dailyWatchTime: {},
        topCreators: [],
        longestVideos: [],
        periodDays: 7,
      );

      expect(stats.formattedWatchTime, '1h 1m');
    });

    test('formats short watch time correctly', () {
      final stats = WatchStatsData(
        totalWatchTimeSeconds: 120, // 2m
        videosWatched: 1,
        uniqueVideoCount: 1,
        uniqueCreatorCount: 1,
        dailyWatchTime: {},
        topCreators: [],
        longestVideos: [],
        periodDays: 1,
      );

      expect(stats.formattedWatchTime, '2m');
    });

    test('calculates daily average', () {
      final stats = WatchStatsData(
        totalWatchTimeSeconds: 7200, // 2h
        videosWatched: 2,
        uniqueVideoCount: 2,
        uniqueCreatorCount: 1,
        dailyWatchTime: {},
        topCreators: [],
        longestVideos: [],
        periodDays: 7,
      );

      expect(stats.dailyAverageSeconds, closeTo(1028.57, 0.1)); // ~17 minutes per day
    });
  });
}
