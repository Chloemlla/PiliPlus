import 'dart:typed_data';

import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/services/playlist_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlaylistImportService.validateJson', () {
    test('validates and parses a correct JSON playlist', () {
      const validJson = '''
      {
        "version": 1,
        "app": "PiliPlus",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Test Playlist",
        "count": 2,
        "videos": [
          {"bvid": "BV1MM4y1s7NZ", "title": "Video 1"},
          {"bvid": "BV13t411n7ex", "title": "Video 2"}
        ]
      }
      ''';

      final result = PlaylistImportService.validateJson(validJson);

      expect(result.isValid, isTrue);
      expect(result.message, '有效');
      expect(result.previewInfo, 'Test Playlist (2 个条目)');
      expect(result.videoCount, 2);
      expect(result.playlistData?.videos.length, 2);
    });

    test('accepts following-series references for backup preview', () {
      const validJson = '''
      {
        "version": 1,
        "app": "PiliPlus",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Following",
        "count": 1,
        "videos": [
          {"itemType": "season", "seasonId": 12345, "title": "Season"}
        ]
      }
      ''';

      final result = PlaylistImportService.validateJson(validJson);

      expect(result.isValid, isTrue);
      expect(result.playlistData?.videos.single.isSeason, isTrue);
    });

    test('rejects malformed JSON and non-object roots', () {
      final malformed = PlaylistImportService.validateJson('not json');
      final listRoot = PlaylistImportService.validateJson('[]');

      expect(malformed.isValid, isFalse);
      expect(malformed.message, contains('JSON 格式解析失败'));
      expect(listRoot.isValid, isFalse);
      expect(listRoot.message, '无效的播放列表格式');
    });

    test('rejects a non-PiliPlus source', () {
      const wrongAppJson = '''
      {
        "version": 1,
        "app": "OtherApp",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Test",
        "count": 0,
        "videos": []
      }
      ''';

      final result = PlaylistImportService.validateJson(wrongAppJson);

      expect(result.isValid, isFalse);
      expect(result.message, '无效的播放列表来源');
    });

    test('rejects unsupported versions', () {
      const futureVersionJson = '''
      {
        "version": 99,
        "app": "PiliPlus",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Test",
        "count": 0,
        "videos": []
      }
      ''';

      final result = PlaylistImportService.validateJson(futureVersionJson);

      expect(result.isValid, isFalse);
      expect(result.message, contains('不支持的播放列表版本'));
    });

    test('rejects missing videos and mismatched counts', () {
      const missingVideosJson = '''
      {
        "version": 1,
        "app": "PiliPlus",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Test",
        "count": 0
      }
      ''';
      const mismatchedCountJson = '''
      {
        "version": 1,
        "app": "PiliPlus",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Test",
        "count": 2,
        "videos": [
          {"bvid": "BV1MM4y1s7NZ", "title": "Video"}
        ]
      }
      ''';

      final missing = PlaylistImportService.validateJson(missingVideosJson);
      final mismatched = PlaylistImportService.validateJson(
        mismatchedCountJson,
      );

      expect(missing.isValid, isFalse);
      expect(missing.message, '缺少视频列表');
      expect(mismatched.isValid, isFalse);
      expect(mismatched.message, contains('视频数量不一致'));
    });

    test('rejects malformed video references', () {
      const invalidBvidJson = '''
      {
        "version": 1,
        "app": "PiliPlus",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Test",
        "count": 1,
        "videos": [
          {"bvid": "not-a-bvid", "title": "Video"}
        ]
      }
      ''';

      final result = PlaylistImportService.validateJson(invalidBvidJson);

      expect(result.isValid, isFalse);
      expect(result.message, '第 1 个视频的 bvid 无效');
    });

    test('rejects oversized import text before parsing', () {
      final oversized = String.fromCharCodes(
        Uint8List(PlaylistImportService.maxImportFileBytes + 1),
      );
      final result = PlaylistImportService.validateJson(
        oversized,
      );

      expect(result.isValid, isFalse);
      expect(result.message, contains('文件过大'));
    });
  });

  group('PlaylistImportService.importPlaylist', () {
    test('skips destination duplicates without issuing an API write', () async {
      const json = '''
      {
        "version": 1,
        "app": "PiliPlus",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Test",
        "count": 1,
        "videos": [
          {"bvid": "BV1MM4y1s7NZ", "title": "Video"}
        ]
      }
      ''';

      final result = await PlaylistImportService.importPlaylist(
        jsonString: json,
        destination: ImportDestination.watchLater,
        existingBvids: {'BV1MM4y1s7NZ'},
      );

      expect(result.isSuccess, isTrue);
      expect(result.data.importedCount, 0);
      expect(result.data.duplicateCount, 1);
      expect(result.data.summary, '已导入 0 个视频，已跳过 1 个重复');
    });

    test(
      'reports season-only backups as unsupported without API writes',
      () async {
        const json = '''
      {
        "version": 1,
        "app": "PiliPlus",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Following",
        "count": 1,
        "videos": [
          {"itemType": "season", "seasonId": 12345, "title": "Season"}
        ]
      }
      ''';

        final result = await PlaylistImportService.importPlaylist(
          jsonString: json,
          destination: ImportDestination.watchLater,
        );

        expect(result.isSuccess, isTrue);
        expect(result.data.importedCount, 0);
        expect(result.data.unsupportedCount, 1);
        expect(result.data.summary, '已导入 0 个视频，忽略 1 个追番/追剧条目');
      },
    );

    test(
      'writes each unique watch-later BVID once and reports repeats',
      () async {
        const json = '''
      {
        "version": 1,
        "app": "PiliPlus",
        "exportedAt": "2026-07-31T00:00:00.000Z",
        "playlistName": "Repeated",
        "count": 2,
        "videos": [
          {"bvid": "BV1MM4y1s7NZ", "title": "Video 1"},
          {"bvid": "BV1MM4y1s7NZ", "title": "Video 1 again"}
        ]
      }
      ''';
        final writtenBvids = <String>[];

        final result = await PlaylistImportService.importPlaylist(
          jsonString: json,
          destination: ImportDestination.watchLater,
          existingBvids: const {},
          watchLaterWriter: (bvid) async {
            writtenBvids.add(bvid);
            return const Success(null);
          },
        );

        expect(result.isSuccess, isTrue);
        expect(writtenBvids, const ['BV1MM4y1s7NZ']);
        expect(result.data.importedCount, 1);
        expect(result.data.duplicateCount, 1);
      },
    );
  });

  test('ImportDestination exposes the two PRD destinations', () {
    expect(ImportDestination.values, const [
      ImportDestination.watchLater,
      ImportDestination.importedFavorite,
    ]);
  });
}
