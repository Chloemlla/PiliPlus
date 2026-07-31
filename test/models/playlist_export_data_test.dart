import 'package:pili_plus/models/playlist_export_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlaylistVideoItem', () {
    test('round-trips a video entry with metadata', () {
      final addedAt = DateTime.utc(2026, 7, 31, 12, 30);
      final item = PlaylistVideoItem(
        bvid: 'BV1MM4y1s7NZ',
        title: 'Test Video',
        cover: 'https://example.com/cover.jpg',
        author: 'Test Author',
        authorMid: 123456,
        duration: 300,
        addedAt: addedAt,
        description: 'Test description',
      );

      final restored = PlaylistVideoItem.fromJson(item.toJson());

      expect(restored.itemType, PlaylistItemType.video);
      expect(restored.bvid, item.bvid);
      expect(restored.title, item.title);
      expect(restored.cover, item.cover);
      expect(restored.author, item.author);
      expect(restored.authorMid, item.authorMid);
      expect(restored.duration, item.duration);
      expect(restored.addedAt, addedAt);
      expect(restored.description, item.description);
      expect(restored.referenceUrl, contains(item.bvid!));
    });

    test('round-trips a following-series entry', () {
      const item = PlaylistVideoItem(
        itemType: PlaylistItemType.season,
        seasonId: 12345,
        title: 'Test Season',
      );

      final restored = PlaylistVideoItem.fromJson(item.toJson());

      expect(restored.isSeason, isTrue);
      expect(restored.referenceLabel, 'ss12345');
      expect(
        restored.referenceUrl,
        'https://www.bilibili.com/bangumi/play/ss12345',
      );
    });

    test('rejects an entry without its required reference', () {
      expect(
        () => PlaylistVideoItem.fromJson(const {
          'itemType': 'video',
          'title': 'Missing BVID',
        }),
        throwsFormatException,
      );
      expect(
        () => PlaylistVideoItem.fromJson(const {
          'itemType': 'season',
          'title': 'Missing season id',
        }),
        throwsFormatException,
      );
    });
  });

  group('PlaylistExportData', () {
    test('round-trips schema version 1 and derives count', () {
      final exportedAt = DateTime.utc(2026, 7, 31);
      final data = PlaylistExportData(
        exportedAt: exportedAt,
        playlistName: 'My Playlist',
        videos: const [
          PlaylistVideoItem(bvid: 'BV1MM4y1s7NZ', title: 'Video 1'),
          PlaylistVideoItem(bvid: 'BV1Q541167Qg', title: 'Video 2'),
        ],
      );

      final restored = PlaylistExportData.fromJson(data.toJson());

      expect(restored.version, PlaylistExportData.currentVersion);
      expect(restored.app, PlaylistExportData.appName);
      expect(restored.exportedAt, exportedAt);
      expect(restored.playlistName, data.playlistName);
      expect(restored.count, 2);
      expect(restored.videos.first.bvid, 'BV1MM4y1s7NZ');
    });

    test('rejects a count that does not match the entry list', () {
      expect(
        () => PlaylistExportData.fromJson(const {
          'version': 1,
          'app': 'PiliPlus',
          'exportedAt': '2026-07-31T00:00:00.000Z',
          'playlistName': 'Broken',
          'count': 2,
          'videos': [
            {'bvid': 'BV1MM4y1s7NZ', 'title': 'Only one'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('writes video and season references to M3U8', () {
      final data = PlaylistExportData(
        exportedAt: DateTime.utc(2026, 7, 31),
        playlistName: 'Test Playlist',
        videos: const [
          PlaylistVideoItem(
            bvid: 'BV1MM4y1s7NZ',
            title: 'Test Video',
            author: 'Test Author',
            duration: 3661,
          ),
          PlaylistVideoItem(
            itemType: PlaylistItemType.season,
            seasonId: 12345,
            title: 'Test Season',
          ),
        ],
      );

      final m3u8 = data.toM3U8();

      expect(m3u8, startsWith('#EXTM3U\n'));
      expect(m3u8, contains('#EXTINF:3661,Test Video'));
      expect(m3u8, contains('#EXTV-BVID:BV1MM4y1s7NZ'));
      expect(m3u8, contains('https://www.bilibili.com/video/BV1MM4y1s7NZ'));
      expect(m3u8, contains('#EXTV-SEASON-ID:12345'));
      expect(
        m3u8,
        contains('https://www.bilibili.com/bangumi/play/ss12345'),
      );
      expect(m3u8, endsWith('#EXT-X-ENDLIST\n'));
    });

    test('escapes quotes and line breaks in M3U8 metadata', () {
      final data = PlaylistExportData(
        exportedAt: DateTime.utc(2026, 7, 31),
        playlistName: 'Test',
        videos: const [
          PlaylistVideoItem(
            bvid: 'BV1MM4y1s7NZ',
            title: 'Video with "quotes" and\nnewlines',
          ),
        ],
      );

      final m3u8 = data.toM3U8();

      expect(m3u8, contains(r'Video with \"quotes\" and\nnewlines'));
      expect(m3u8, isNot(contains('and\nnewlines\n#EXTV-BVID')));
    });
  });

  group('PlaylistImportResult', () {
    test('formats a clean import summary', () {
      const result = PlaylistImportResult(
        totalCount: 10,
        importedCount: 10,
        duplicateCount: 0,
        unsupportedCount: 0,
        failedCount: 0,
        duplicateBvids: [],
        failedBvids: [],
      );

      expect(result.summary, '已导入 10 个视频');
      expect(result.skippedCount, 0);
    });

    test(
      'reports duplicates, unsupported entries, and failures separately',
      () {
        const result = PlaylistImportResult(
          totalCount: 10,
          importedCount: 5,
          duplicateCount: 3,
          unsupportedCount: 1,
          failedCount: 1,
          duplicateBvids: ['BV1MM4y1s7NZ'],
          failedBvids: ['BV1Q541167Qg'],
        );

        expect(
          result.summary,
          '已导入 5 个视频，跳过 3 个重复，忽略 1 个追番/追剧条目，1 个导入失败',
        );
        expect(result.skippedCount, 5);
      },
    );
  });
}
