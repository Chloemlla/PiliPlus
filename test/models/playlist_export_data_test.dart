import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/playlist_export_data.dart';

void main() {
  group('PlaylistVideoItem', () {
    test('should create video item with all fields', () {
      final addedAt = DateTime.now();
      final item = PlaylistVideoItem(
        bvid: 'BV123456',
        title: 'Test Video',
        cover: 'https://example.com/cover.jpg',
        author: 'Test Author',
        authorMid: 123456,
        duration: 300,
        addedAt: addedAt,
        description: 'Test description',
      );

      expect(item.bvid, 'BV123456');
      expect(item.title, 'Test Video');
      expect(item.cover, 'https://example.com/cover.jpg');
      expect(item.author, 'Test Author');
      expect(item.authorMid, 123456);
      expect(item.duration, 300);
      expect(item.addedAt, addedAt);
      expect(item.description, 'Test description');
    });

    test('should convert to JSON and back', () {
      final addedAt = DateTime.now();
      final item = PlaylistVideoItem(
        bvid: 'BV123456',
        title: 'Test Video',
        author: 'Test Author',
        duration: 300,
        addedAt: addedAt,
      );

      final json = item.toJson();
      final restored = PlaylistVideoItem.fromJson(json);

      expect(restored.bvid, item.bvid);
      expect(restored.title, item.title);
      expect(restored.author, item.author);
      expect(restored.duration, item.duration);
      expect(restored.addedAt?.toIso8601String(), item.addedAt?.toIso8601String());
    });

    test('should handle null fields in JSON', () {
      final item = PlaylistVideoItem(
        bvid: 'BV123456',
        title: 'Test Video',
      );

      final json = item.toJson();
      expect(json['cover'], null);
      expect(json['author'], null);
      expect(json['authorMid'], null);
      expect(json['duration'], null);
      expect(json['addedAt'], null);

      final restored = PlaylistVideoItem.fromJson(json);
      expect(restored.cover, null);
      expect(restored.author, null);
      expect(restored.authorMid, null);
    });
  });

  group('PlaylistExportData', () {
    test('should create export data', () {
      final now = DateTime.now();
      final videos = [
        PlaylistVideoItem(bvid: 'BV1', title: 'Video 1'),
        PlaylistVideoItem(bvid: 'BV2', title: 'Video 2'),
      ];

      final data = PlaylistExportData(
        exportedAt: now,
        playlistName: 'My Playlist',
        videos: videos,
      );

      expect(data.version, 1);
      expect(data.app, 'PiliPlus');
      expect(data.playlistName, 'My Playlist');
      expect(data.count, 2);
      expect(data.videos.length, 2);
    });

    test('should convert to JSON and back', () {
      final now = DateTime.now();
      final videos = [
        PlaylistVideoItem(bvid: 'BV1', title: 'Video 1', duration: 120),
        PlaylistVideoItem(bvid: 'BV2', title: 'Video 2', duration: 240),
      ];

      final data = PlaylistExportData(
        exportedAt: now,
        playlistName: 'My Playlist',
        videos: videos,
      );

      final json = data.toJson();
      final restored = PlaylistExportData.fromJson(json);

      expect(restored.version, data.version);
      expect(restored.app, data.app);
      expect(restored.playlistName, data.playlistName);
      expect(restored.count, data.count);
      expect(restored.videos.length, data.videos.length);
      expect(restored.videos[0].bvid, 'BV1');
      expect(restored.videos[1].bvid, 'BV2');
    });

    test('should convert to M3U8 format', () {
      final videos = [
        PlaylistVideoItem(
          bvid: 'BV123456',
          title: 'Test Video 1',
          author: 'Test Author',
          duration: 3661,
        ),
        PlaylistVideoItem(
          bvid: 'BV654321',
          title: 'Test Video 2',
          duration: 120,
        ),
      ];

      final data = PlaylistExportData(
        exportedAt: DateTime.now(),
        playlistName: 'Test Playlist',
        videos: videos,
      );

      final m3u8 = data.toM3U8();

      expect(m3u8, contains('#EXTM3U'));
      expect(m3u8, contains('# PlayList exported by PiliPlus'));
      expect(m3u8, contains('#EXTINF:3661,Test Video 1'));
      expect(m3u8, contains('#EXTV-BVID:BV123456'));
      expect(m3u8, contains('#EXTV-AUTHOR:Test Author'));
      expect(m3u8, contains('#EXTINF:120,Test Video 2'));
      expect(m3u8, contains('#EXTV-BVID:BV654321'));
      expect(m3u8, contains('#EXT-X-ENDLIST'));
    });

    test('should escape special characters in M3U8', () {
      final videos = [
        PlaylistVideoItem(
          bvid: 'BV123',
          title: 'Video with "quotes" and\nnewlines',
          duration: 100,
        ),
      ];

      final data = PlaylistExportData(
        exportedAt: DateTime.now(),
        playlistName: 'Test',
        videos: videos,
      );

      final m3u8 = data.toM3U8();
      // The escaped version should not contain raw quotes or newlines
      expect(m3u8.contains('"quotes"'), false);
    });
  });

  group('PlaylistImportResult', () {
    test('should format summary without skipped', () {
      final result = PlaylistImportResult(
        totalCount: 10,
        importedCount: 10,
        skippedCount: 0,
        skippedBvids: [],
      );

      expect(result.summary, '成功导入 10 个视频');
    });

    test('should format summary with skipped', () {
      final result = PlaylistImportResult(
        totalCount: 10,
        importedCount: 7,
        skippedCount: 3,
        skippedBvids: ['BV1', 'BV2', 'BV3'],
      );

      expect(result.summary, '已导入 7 个视频，跳过 3 个重复');
    });
  });
}
