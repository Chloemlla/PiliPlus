import 'dart:convert';

import 'package:pili_plus/http/fav.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/user.dart';
import 'package:pili_plus/models/playlist_export_data.dart';
import 'package:pili_plus/services/playlist_export_service.dart';
import 'package:pili_plus/utils/bili_utils.dart';
import 'package:pili_plus/utils/id_utils.dart';

typedef WatchLaterPlaylistWriter =
    Future<LoadingState<void>> Function(String bvid);

abstract final class PlaylistImportService {
  static const String importedFolderName = '已导入';
  static const int maxImportFileBytes = 8 * 1024 * 1024;
  static const int maxImportEntries = 10000;
  static const int _favoriteBatchSize = 20;

  static Future<LoadingState<PlaylistImportResult>> importPlaylist({
    required String jsonString,
    required ImportDestination destination,
    Set<String>? existingBvids,
    WatchLaterPlaylistWriter? watchLaterWriter,
  }) async {
    final validation = validateJson(jsonString);
    final playlistData = validation.playlistData;
    if (!validation.isValid || playlistData == null) {
      return Error(validation.message);
    }

    try {
      return await _processImport(
        playlistData: playlistData,
        destination: destination,
        existingBvids: existingBvids,
        watchLaterWriter: watchLaterWriter ?? _writeWatchLaterSilently,
      );
    } catch (error) {
      return Error('导入失败: $error');
    }
  }

  static Future<LoadingState<PlaylistImportResult>> _processImport({
    required PlaylistExportData playlistData,
    required ImportDestination destination,
    Set<String>? existingBvids,
    required WatchLaterPlaylistWriter watchLaterWriter,
  }) async {
    final videoBvids = <String>[];
    int unsupportedCount = 0;
    for (final entry in playlistData.videos) {
      final bvid = entry.bvid;
      if (entry.itemType == PlaylistItemType.video && bvid != null) {
        videoBvids.add(bvid);
      } else {
        unsupportedCount++;
      }
    }

    if (videoBvids.isEmpty) {
      return Success(
        PlaylistImportResult(
          totalCount: playlistData.count,
          importedCount: 0,
          duplicateCount: 0,
          unsupportedCount: unsupportedCount,
          failedCount: 0,
          duplicateBvids: const [],
          failedBvids: const [],
        ),
      );
    }

    final targetResult = await _resolveTarget(
      destination: destination,
      existingBvids: existingBvids,
    );
    final _ImportTarget target;
    if (targetResult case Success(:final response)) {
      target = response;
    } else {
      return _errorFrom(targetResult, '无法读取导入目标');
    }

    final knownBvids = <String>{...target.existingBvids};
    final bvidsToImport = <String>[];
    final duplicateBvids = <String>[];
    for (final bvid in videoBvids) {
      if (knownBvids.add(bvid)) {
        bvidsToImport.add(bvid);
      } else {
        duplicateBvids.add(bvid);
      }
    }

    if (bvidsToImport.isEmpty) {
      return Success(
        PlaylistImportResult(
          totalCount: playlistData.count,
          importedCount: 0,
          duplicateCount: duplicateBvids.length,
          unsupportedCount: unsupportedCount,
          failedCount: 0,
          duplicateBvids: duplicateBvids,
          failedBvids: const [],
        ),
      );
    }

    final _WriteResult written;
    switch (destination) {
      case ImportDestination.watchLater:
        written = await _importToWatchLater(
          bvidsToImport,
          writer: watchLaterWriter,
        );
        break;
      case ImportDestination.importedFavorite:
        final mediaId = target.favoriteMediaId;
        if (mediaId == null) {
          return const Error('导入收藏夹无效');
        }
        written = await _importToFavorite(
          bvids: bvidsToImport,
          mediaId: mediaId,
        );
        break;
    }

    return Success(
      PlaylistImportResult(
        totalCount: playlistData.count,
        importedCount: written.importedCount,
        duplicateCount: duplicateBvids.length,
        unsupportedCount: unsupportedCount,
        failedCount: written.failedBvids.length,
        duplicateBvids: duplicateBvids,
        failedBvids: written.failedBvids,
      ),
    );
  }

  static Future<LoadingState<_ImportTarget>> _resolveTarget({
    required ImportDestination destination,
    Set<String>? existingBvids,
  }) async {
    switch (destination) {
      case ImportDestination.watchLater:
        if (existingBvids != null) {
          return Success(
            _ImportTarget(existingBvids: Set<String>.of(existingBvids)),
          );
        }
        final result = await PlaylistExportService.getWatchLaterVideos();
        if (result case Success(:final response)) {
          return Success(
            _ImportTarget(
              existingBvids: {
                for (final video in response)
                  ?video.bvid,
              },
            ),
          );
        }
        return _errorFrom(result, '获取稍后再看列表失败');

      case ImportDestination.importedFavorite:
        final folderResult = await _getOrCreateImportedFolder();
        final int folderId;
        if (folderResult case Success(:final response)) {
          folderId = response;
        } else {
          return _errorFrom(folderResult, '创建“$importedFolderName”收藏夹失败');
        }
        if (existingBvids != null) {
          return Success(
            _ImportTarget(
              favoriteMediaId: folderId,
              existingBvids: Set<String>.of(existingBvids),
            ),
          );
        }
        final videosResult = await PlaylistExportService.getFavoriteVideos(
          mediaId: folderId,
        );
        if (videosResult case Success(:final response)) {
          return Success(
            _ImportTarget(
              favoriteMediaId: folderId,
              existingBvids: {
                for (final video in response)
                  ?video.bvid,
              },
            ),
          );
        }
        return _errorFrom(videosResult, '读取“$importedFolderName”收藏夹失败');
    }
  }

  static Future<LoadingState<int>> _getOrCreateImportedFolder() async {
    final foldersResult = await PlaylistExportService.getFavoriteFolders();
    if (foldersResult case Success(:final response)) {
      for (final folder in response) {
        if (folder.title == importedFolderName &&
            !BiliUtils.isPublicFav(folder.attr)) {
          return Success(folder.id);
        }
      }
    } else {
      return _errorFrom(foldersResult, '获取收藏夹失败');
    }

    final createResult = await FavHttp.addOrEditFolder(
      isAdd: true,
      title: importedFolderName,
      privacy: 1,
      cover: '',
      intro: '由 PiliPlus 播放列表导入功能创建',
    );
    if (createResult case Success(:final response)) {
      return Success(response.id);
    }
    return _errorFrom(createResult, '创建“$importedFolderName”收藏夹失败');
  }

  static Future<_WriteResult> _importToWatchLater(
    List<String> bvids, {
    required WatchLaterPlaylistWriter writer,
  }) async {
    int importedCount = 0;
    final failedBvids = <String>[];
    for (final bvid in bvids) {
      final result = await writer(bvid);
      if (result.isSuccess) {
        importedCount++;
      } else {
        failedBvids.add(bvid);
      }
    }
    return _WriteResult(
      importedCount: importedCount,
      failedBvids: failedBvids,
    );
  }

  static Future<LoadingState<void>> _writeWatchLaterSilently(String bvid) =>
      UserHttp.toViewLater(bvid: bvid, showToast: false);

  static Future<_WriteResult> _importToFavorite({
    required List<String> bvids,
    required int mediaId,
  }) async {
    int importedCount = 0;
    final failedBvids = <String>[];
    for (int start = 0; start < bvids.length; start += _favoriteBatchSize) {
      final candidateEnd = start + _favoriteBatchSize;
      final end = candidateEnd < bvids.length ? candidateEnd : bvids.length;
      final batch = bvids.sublist(start, end);
      final resources = batch
          .map((bvid) => '${IdUtils.bv2av(bvid)}:2')
          .join(',');
      final result = await FavHttp.favVideo(
        resources: resources,
        addIds: mediaId.toString(),
      );
      if (result.isSuccess) {
        importedCount += batch.length;
      } else {
        failedBvids.addAll(batch);
      }
    }
    return _WriteResult(
      importedCount: importedCount,
      failedBvids: failedBvids,
    );
  }

  static ValidationResult validateJson(String jsonString) {
    if (utf8.encode(jsonString).length > maxImportFileBytes) {
      return const ValidationResult(
        isValid: false,
        message: '播放列表文件过大（最大 8 MiB）',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException catch (error) {
      return ValidationResult(
        isValid: false,
        message: 'JSON 格式解析失败: ${error.message}',
      );
    }

    if (decoded is! Map) {
      return const ValidationResult(
        isValid: false,
        message: '无效的播放列表格式',
      );
    }

    final json = Map<String, dynamic>.from(decoded);
    final version = json['version'];
    if (version is! int || version != PlaylistExportData.currentVersion) {
      return ValidationResult(
        isValid: false,
        message: '不支持的播放列表版本: $version',
      );
    }
    if (json['app'] != PlaylistExportData.appName) {
      return const ValidationResult(
        isValid: false,
        message: '无效的播放列表来源',
      );
    }
    final count = json['count'];
    if (count is int && count > maxImportEntries) {
      return const ValidationResult(
        isValid: false,
        message: '播放列表条目过多（最大 10000 条）',
      );
    }
    final videos = json['videos'];
    if (videos is List && videos.length > maxImportEntries) {
      return const ValidationResult(
        isValid: false,
        message: '播放列表条目过多（最大 10000 条）',
      );
    }

    final PlaylistExportData playlistData;
    try {
      playlistData = PlaylistExportData.fromJson(json);
    } on FormatException catch (error) {
      return ValidationResult(
        isValid: false,
        message: error.message.toString(),
      );
    }

    for (final (index, video) in playlistData.videos.indexed) {
      final bvid = video.bvid;
      if (video.itemType == PlaylistItemType.video &&
          (bvid == null || !_isValidBvid(bvid))) {
        return ValidationResult(
          isValid: false,
          message: '第 ${index + 1} 个视频的 bvid 无效',
        );
      }
    }

    return ValidationResult(
      isValid: true,
      message: '有效',
      previewInfo: '${playlistData.playlistName} (${playlistData.count} 个条目)',
      videoCount: playlistData.count,
      playlistData: playlistData,
    );
  }

  static bool _isValidBvid(String bvid) {
    if (!IdUtils.bvRegexExact.hasMatch(bvid)) {
      return false;
    }
    try {
      IdUtils.bv2av(bvid);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Error _errorFrom<T>(LoadingState<T> result, String fallback) {
    if (result case Error(:final errMsg, :final code)) {
      return Error(errMsg ?? fallback, code: code);
    }
    return Error(fallback);
  }
}

enum ImportDestination {
  watchLater,
  importedFavorite,
}

class ValidationResult {
  final bool isValid;
  final String message;
  final String? previewInfo;
  final int? videoCount;
  final PlaylistExportData? playlistData;

  const ValidationResult({
    required this.isValid,
    required this.message,
    this.previewInfo,
    this.videoCount,
    this.playlistData,
  });
}

class _ImportTarget {
  final int? favoriteMediaId;
  final Set<String> existingBvids;

  const _ImportTarget({
    this.favoriteMediaId,
    required this.existingBvids,
  });
}

class _WriteResult {
  final int importedCount;
  final List<String> failedBvids;

  const _WriteResult({
    required this.importedCount,
    required this.failedBvids,
  });
}
