import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/services/playlist_import_service.dart';

void main() {
  group('PlaylistImportService', () {
    group('validateJson', () {
      test('should validate correct JSON', () {
        const validJson = '''
        {
          "version": 1,
          "app": "PiliPlus",
          "exportedAt": "2024-01-01T00:00:00.000",
          "playlistName": "Test Playlist",
          "count": 2,
          "videos": [
            {"bvid": "BV1", "title": "Video 1"},
            {"bvid": "BV2", "title": "Video 2"}
          ]
        }
        ''';

        final result = PlaylistImportService.validateJson(validJson);

        expect(result.isValid, true);
        expect(result.message, '有效');
        expect(result.previewInfo, 'Test Playlist (2 个视频)');
        expect(result.videoCount, 2);
      });

      test('should reject invalid JSON format', () {
        const invalidJson = 'not a json object';

        final result = PlaylistImportService.validateJson(invalidJson);

        expect(result.isValid, false);
        expect(result.message, contains('JSON 格式解析失败'));
      });

      test('should reject non-PiliPlus app', () {
        const wrongAppJson = '''
        {
          "version": 1,
          "app": "OtherApp",
          "exportedAt": "2024-01-01T00:00:00.000",
          "playlistName": "Test",
          "videos": []
        }
        ''';

        final result = PlaylistImportService.validateJson(wrongAppJson);

        expect(result.isValid, false);
        expect(result.message, '无效的播放列表来源');
      });

      test('should reject unsupported version', () {
        const futureVersionJson = '''
        {
          "version": 99,
          "app": "PiliPlus",
          "exportedAt": "2024-01-01T00:00:00.000",
          "playlistName": "Test",
          "videos": []
        }
        ''';

        final result = PlaylistImportService.validateJson(futureVersionJson);

        expect(result.isValid, false);
        expect(result.message, contains('不支持的播放列表版本'));
      });

      test('should reject missing videos', () {
        const missingVideosJson = '''
        {
          "version": 1,
          "app": "PiliPlus",
          "exportedAt": "2024-01-01T00:00:00.000",
          "playlistName": "Test"
        }
        ''';

        final result = PlaylistImportService.validateJson(missingVideosJson);

        expect(result.isValid, false);
        expect(result.message, '缺少视频列表');
      });
    });
  });

  group('ImportDestination', () {
    test('should have correct values', () {
      expect(ImportDestination.values.length, 3);
      expect(ImportDestination.values, contains(ImportDestination.watchLater));
      expect(ImportDestination.values, contains(ImportDestination.createNew));
      expect(ImportDestination.values, contains(ImportDestination.specified));
    });
  });
}
