import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/video_bookmark.dart';

void main() {
  group('VideoBookmark', () {
    test('uses the reserved Hive adapter type ID', () {
      expect(VideoBookmarkAdapter().typeId, 100);
    });

    test('should create bookmark with all fields', () {
      final now = DateTime.now();
      final bookmark = VideoBookmark(
        id: 'bm_1',
        bvid: 'BV123456',
        videoTitle: 'Test Video',
        authorMid: 123456,
        timestampSeconds: 3661,
        name: 'Important Part',
        note: 'Review this',
        createdAt: now,
      );

      expect(bookmark.id, 'bm_1');
      expect(bookmark.bvid, 'BV123456');
      expect(bookmark.videoTitle, 'Test Video');
      expect(bookmark.authorMid, 123456);
      expect(bookmark.timestampSeconds, 3661);
      expect(bookmark.name, 'Important Part');
      expect(bookmark.note, 'Review this');
      expect(bookmark.createdAt, now);
    });

    test('should format timestamp correctly without hours', () {
      final bookmark = VideoBookmark(
        id: 'bm_1',
        bvid: 'BV123456',
        videoTitle: 'Test Video',
        timestampSeconds: 125, // 2:05
        name: 'Test',
        createdAt: DateTime.now(),
      );

      expect(bookmark.formattedTimestamp, '02:05');
    });

    test('should format timestamp correctly with hours', () {
      final bookmark = VideoBookmark(
        id: 'bm_1',
        bvid: 'BV123456',
        videoTitle: 'Test Video',
        timestampSeconds: 3723, // 1:02:03
        name: 'Test',
        createdAt: DateTime.now(),
      );

      expect(bookmark.formattedTimestamp, '01:02:03');
    });

    test('should clamp negative timestamps when formatting', () {
      expect(VideoBookmark.formatTimestamp(-1), '00:00');
    });

    test('should convert to JSON and back', () {
      final now = DateTime.now();
      final bookmark = VideoBookmark(
        id: 'bm_1',
        bvid: 'BV123456',
        videoTitle: 'Test Video',
        authorMid: 123456,
        timestampSeconds: 3661,
        name: 'Important Part',
        note: 'Review this',
        createdAt: now,
      );

      final json = bookmark.toJson();
      final restored = VideoBookmark.fromJson(json);

      expect(restored.id, bookmark.id);
      expect(restored.bvid, bookmark.bvid);
      expect(restored.videoTitle, bookmark.videoTitle);
      expect(restored.authorMid, bookmark.authorMid);
      expect(restored.timestampSeconds, bookmark.timestampSeconds);
      expect(restored.name, bookmark.name);
      expect(restored.note, bookmark.note);
      expect(restored.createdAt, bookmark.createdAt);
    });

    test('should handle null note in JSON', () {
      final bookmark = VideoBookmark(
        id: 'bm_1',
        bvid: 'BV123456',
        videoTitle: 'Test Video',
        timestampSeconds: 100,
        name: 'Test',
        note: null,
        createdAt: DateTime.now(),
      );

      final json = bookmark.toJson();
      expect(json['note'], null);

      final restored = VideoBookmark.fromJson(json);
      expect(restored.note, null);
    });

    test('rejects malformed imported fields with FormatException', () {
      expect(
        () => VideoBookmark.fromJson(const {
          'id': '',
          'bvid': 'BV1MM4y1s7NZ',
          'videoTitle': 'Video',
          'timestampSeconds': -1,
          'name': 'Bookmark',
          'createdAt': 'not-a-date',
        }),
        throwsFormatException,
      );
    });

    test('should copyWith create new instance with updated fields', () {
      final original = VideoBookmark(
        id: 'bm_1',
        bvid: 'BV123456',
        videoTitle: 'Test Video',
        timestampSeconds: 100,
        name: 'Original Name',
        createdAt: DateTime.now(),
      );

      final copied = original.copyWith(name: 'Updated Name', note: 'New note');

      expect(copied.id, original.id);
      expect(copied.bvid, original.bvid);
      expect(copied.name, 'Updated Name');
      expect(copied.note, 'New note');
      expect(original.name, 'Original Name');
      expect(original.note, null);
    });

    test('should replace editable details and allow clearing the note', () {
      final original = VideoBookmark(
        id: 'bm_1',
        bvid: 'BV123456',
        videoTitle: 'Test Video',
        timestampSeconds: 100,
        name: 'Original Name',
        note: 'Original note',
        createdAt: DateTime.now(),
      );

      final updated = original.copyWithDetails(
        name: 'Updated Name',
        note: null,
      );

      expect(updated.name, 'Updated Name');
      expect(updated.note, isNull);
      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
      expect(original.note, 'Original note');
    });
  });
}
