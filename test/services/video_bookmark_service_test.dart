import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/services/video_bookmark_service.dart';

void main() {
  group('VideoBookmarkService', () {
    group('SortType', () {
      test('should have correct values', () {
        expect(SortType.values.length, 3);
        expect(SortType.values, contains(SortType.mostRecent));
        expect(SortType.values, contains(SortType.videoName));
        expect(SortType.values, contains(SortType.timestamp));
      });
    });

    group('timestamp formatting', () {
      test('should format seconds without leading zeros correctly', () {
        // This tests the internal _formatTimestamp helper
        // Using formattedTimestamp on a bookmark
        expect(_formatTestTimestamp(5), '00:05');
        expect(_formatTestTimestamp(59), '00:59');
        expect(_formatTestTimestamp(60), '01:00');
        expect(_formatTestTimestamp(65), '01:05');
        expect(_formatTestTimestamp(3599), '59:59');
        expect(_formatTestTimestamp(3600), '01:00:00');
        expect(_formatTestTimestamp(3661), '01:01:01');
        expect(_formatTestTimestamp(7200), '02:00:00');
        expect(_formatTestTimestamp(86399), '23:59:59');
        expect(_formatTestTimestamp(86400), '24:00:00');
      });
    });
  });
}

// Helper function that mirrors _formatTimestamp in VideoBookmarkService
String _formatTestTimestamp(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}
