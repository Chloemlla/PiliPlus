import 'dart:convert';
import 'package:pili_plus/http/fav.dart';
import 'package:pili_plus/http/user.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models/playlist_export_data.dart';
import 'package:pili_plus/utils/accounts.dart';

class PlaylistImportService {
  /// Import playlist from JSON data
  static Future<LoadingState<PlaylistImportResult>> importPlaylist({
    required String jsonString,
    required ImportDestination destination,
    Set<String>? existingBvids,
  }) async {
    try {
      final data = jsonDecode(jsonString);
      if (data is! Map<String, dynamic>) {
        return const Error('无效的播放列表格式');
      }

      // Validate version
      final version = data['version'] as int?;
      if (version == null || version > 1) {
        return const Error('不支持的播放列表版本');
      }

      // Validate app
      final app = data['app'] as String?;
      if (app != 'PiliPlus') {
        return const Error('无效的播放列表来源');
      }

      final playlistData = PlaylistExportData.fromJson(data);
      return _processImport(
        playlistData: playlistData,
        destination: destination,
        existingBvids: existingBvids,
      );
    } on FormatException {
      return const Error('JSON 格式解析失败');
    } catch (e) {
      return Error('导入失败: $e');
    }
  }

  /// Import from m3u8 format (extracts bvid references only)
  static Future<LoadingState<PlaylistImportResult>> importFromM3U8({
    required String m3u8Content,
    required ImportDestination destination,
    Set<String>? existingBvids,
  }) async {
    try {
      final bvids = _extractBvidsFromM3U8(m3u8Content);
      if (bvids.isEmpty) {
        return const Error('m3u8 文件中未找到视频');
      }

      final videos = bvids.map((bvid) => PlaylistVideoItem(
        bvid: bvid,
        title: '视频 $bvid',
      )).toList();

      final playlistData = PlaylistExportData(
        exportedAt: DateTime.now(),
        playlistName: '导入的播放列表',
        videos: videos,
      );

      return _processImport(
        playlistData: playlistData,
        destination: destination,
        existingBvids: existingBvids,
      );
    } catch (e) {
      return Error('m3u8 解析失败: $e');
    }
  }

  /// Process the import operation
  static Future<LoadingState<PlaylistImportResult>> _processImport({
    required PlaylistExportData playlistData,
    required ImportDestination destination,
    Set<String>? existingBvids,
  }) async {
    final videos = playlistData.videos;
    if (videos.isEmpty) {
      return const Success(PlaylistImportResult(
        totalCount: 0,
        importedCount: 0,
        skippedCount: 0,
        skippedBvids: [],
      ));
    }

    int importedCount = 0;
    int skippedCount = 0;
    final skippedBvids = <String>[];

    for (final video in videos) {
      // Skip duplicates
      if (existingBvids?.contains(video.bvid) == true) {
        skippedCount++;
        skippedBvids.add(video.bvid);
        continue;
      }

      // Add to destination
      final result = await _addToDestination(
        bvid: video.bvid,
        destination: destination,
      );

      if (result) {
        importedCount++;
      } else {
        skippedCount++;
        skippedBvids.add(video.bvid);
      }
    }

    return Success(PlaylistImportResult(
      totalCount: videos.length,
      importedCount: importedCount,
      skippedCount: skippedCount,
      skippedBvids: skippedBvids,
    ));
  }

  /// Add a video to the specified destination
  static Future<bool> _addToDestination({
    required String bvid,
    required ImportDestination destination,
  }) async {
    switch (destination) {
      case ImportDestination.watchLater:
        final result = await UserHttp.toViewLater(bvid: bvid);
        return result.isSuccess;

      case ImportDestination.createNew:
      case ImportDestination.specified:
        // For creating new or specified folder, use favVideo API
        // This would need additional parameters for folder selection
        final result = await FavHttp.favVideo(
          resources: bvid,
          // Would need to add to a specific mediaId
          addIds: null,
        );
        return result.isSuccess;
    }
  }

  /// Extract bvid references from m3u8 content
  static List<String> _extractBvidsFromM3U8(String content) {
    final bvids = <String>[];
    final regex = RegExp(r'#EXTV-BVID:([A-Za-z0-9]+)');
    final matches = regex.allMatches(content);

    for (final match in matches) {
      if (match.groupCount >= 1) {
        bvids.add(match.group(1)!);
      }
    }

    return bvids;
  }

  /// Validate JSON string before import
  static ValidationResult validateJson(String jsonString) {
    try {
      final data = jsonDecode(jsonString);

      if (data is! Map<String, dynamic>) {
        return ValidationResult(
          isValid: false,
          message: '无效的播放列表格式',
        );
      }

      final version = data['version'] as int?;
      final app = data['app'] as String?;
      final playlistName = data['playlistName'] as String?;
      final videos = data['videos'] as List?;

      if (version == null || version > 1) {
        return ValidationResult(
          isValid: false,
          message: '不支持的播放列表版本: $version',
        );
      }

      if (app != 'PiliPlus') {
        return ValidationResult(
          isValid: false,
          message: '无效的播放列表来源',
        );
      }

      if (videos == null) {
        return ValidationResult(
          isValid: false,
          message: '缺少视频列表',
        );
      }

      return ValidationResult(
        isValid: true,
        message: '有效',
        previewInfo: '${playlistName ?? "未知播放列表"} (${videos.length} 个视频)',
        videoCount: videos.length,
      );
    } catch (e) {
      return ValidationResult(
        isValid: false,
        message: 'JSON 格式解析失败: $e',
      );
    }
  }
}

enum ImportDestination {
  watchLater,
  createNew,
  specified,
}

class ValidationResult {
  final bool isValid;
  final String message;
  final String? previewInfo;
  final int? videoCount;

  ValidationResult({
    required this.isValid,
    required this.message,
    this.previewInfo,
    this.videoCount,
  });
}
