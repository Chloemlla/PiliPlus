import 'dart:convert';

import 'package:pili_plus/http/fav.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/http/user.dart';
import 'package:pili_plus/models/playlist_export_data.dart';
import 'package:pili_plus/models_new/fav/fav_detail/media.dart';
import 'package:pili_plus/models_new/fav/fav_folder/list.dart';
import 'package:pili_plus/models_new/fav/fav_pgc/list.dart';
import 'package:pili_plus/models_new/later/list.dart';
import 'package:pili_plus/utils/accounts.dart';

abstract final class PlaylistExportService {
  static const int _pageSize = 20;

  /// Loads every favorite folder owned by the active account.
  static Future<LoadingState<List<FavFolderInfo>>> getFavoriteFolders() async {
    final account = Accounts.main;
    if (!account.isLogin) {
      return const Error('账号未登录');
    }

    final folders = <FavFolderInfo>[];
    int page = 1;
    while (true) {
      final result = await FavHttp.userfavFolder(
        pn: page,
        ps: _pageSize,
        mid: account.mid,
      );
      if (result case Success(:final response)) {
        final pageItems = response.list ?? <FavFolderInfo>[];
        folders.addAll(pageItems);
        if (response.hasMore == false || pageItems.length < _pageSize) {
          break;
        }
        page++;
      } else {
        return _errorFrom(result, '获取收藏夹失败');
      }
    }
    return Success(folders);
  }

  /// Loads and maps all videos in one favorite folder.
  static Future<LoadingState<List<PlaylistVideoItem>>> getFavoriteVideos({
    required int mediaId,
  }) async {
    final items = <FavDetailItemModel>[];
    int page = 1;
    while (true) {
      final result = await FavHttp.userFavFolderDetail(
        mediaId: mediaId,
        pn: page,
        ps: _pageSize,
      );
      if (result case Success(:final response)) {
        final pageItems = response.medias ?? <FavDetailItemModel>[];
        items.addAll(pageItems);
        if (response.hasMore == false || pageItems.length < _pageSize) {
          break;
        }
        page++;
      } else {
        return _errorFrom(result, '获取收藏列表失败');
      }
    }

    return Success([
      for (final item in items)
        if (_favoriteItemToPlaylist(item) case final video?) video,
    ]);
  }

  static Future<LoadingState<PlaylistExportData>> exportFavoriteList({
    required int mediaId,
    required String playlistName,
  }) async {
    final result = await getFavoriteVideos(mediaId: mediaId);
    if (result case Success(:final response)) {
      return Success(
        PlaylistExportData(
          exportedAt: DateTime.now(),
          playlistName: playlistName,
          videos: response,
        ),
      );
    }
    return _errorFrom(result, '导出收藏夹失败');
  }

  /// Loads and maps the complete watch-later list.
  static Future<LoadingState<List<PlaylistVideoItem>>>
  getWatchLaterVideos() async {
    final items = <LaterItemModel>[];
    int page = 1;
    while (true) {
      final result = await UserHttp.seeYouLater(page: page);
      if (result case Success(:final response)) {
        final pageItems = response.list ?? <LaterItemModel>[];
        items.addAll(pageItems);
        final total = response.count;
        if (pageItems.isEmpty || (total != null && items.length >= total)) {
          break;
        }
        page++;
      } else {
        return _errorFrom(result, '获取稍后再看列表失败');
      }
    }

    return Success([
      for (final item in items)
        if (_watchLaterItemToPlaylist(item) case final video?) video,
    ]);
  }

  static Future<LoadingState<PlaylistExportData>> exportWatchLater() async {
    final result = await getWatchLaterVideos();
    if (result case Success(:final response)) {
      return Success(
        PlaylistExportData(
          exportedAt: DateTime.now(),
          playlistName: '稍后再看',
          videos: response,
        ),
      );
    }
    return _errorFrom(result, '导出稍后再看失败');
  }

  /// Exports followed bangumi ([type] 1) or cinema ([type] 2) as season
  /// references. The API does not expose a stable BVID for these entries.
  static Future<LoadingState<PlaylistExportData>> exportFollowingSeries({
    required int type,
    required String playlistName,
  }) async {
    final items = <FavPgcItemModel>[];
    int page = 1;
    while (true) {
      final result = await FavHttp.favPgc(type: type, pn: page);
      if (result case Success(:final response)) {
        final pageItems = response.list ?? <FavPgcItemModel>[];
        items.addAll(pageItems);
        final total = response.total;
        if (pageItems.isEmpty || (total != null && items.length >= total)) {
          break;
        }
        page++;
      } else {
        return _errorFrom(result, '获取$playlistName列表失败');
      }
    }

    final videos = <PlaylistVideoItem>[];
    for (final item in items) {
      final seasonId = item.seasonId;
      if (seasonId == null) {
        continue;
      }
      final descriptionParts = <String>[];
      for (final value in [item.badge, item.progress, item.renewalTime]) {
        if (value != null && value.isNotEmpty) {
          descriptionParts.add(value);
        }
      }
      videos.add(
        PlaylistVideoItem(
          itemType: PlaylistItemType.season,
          seasonId: seasonId,
          title: _titleOrFallback(item.title, 'ss$seasonId'),
          cover: item.cover,
          description: descriptionParts.isEmpty
              ? null
              : descriptionParts.join(' · '),
        ),
      );
    }

    return Success(
      PlaylistExportData(
        exportedAt: DateTime.now(),
        playlistName: playlistName,
        videos: videos,
      ),
    );
  }

  /// Exports all selected sources into one portable file.
  static Future<LoadingState<PlaylistExportData>> exportMultiplePlaylists({
    required Map<int, String> favoriteLists,
    required bool includeWatchLater,
    bool includeBangumi = false,
    bool includeCinema = false,
  }) async {
    final allVideos = <PlaylistVideoItem>[];
    final playlistNames = <String>[];

    for (final entry in favoriteLists.entries) {
      final result = await exportFavoriteList(
        mediaId: entry.key,
        playlistName: entry.value,
      );
      final error = _appendResult(
        result: result,
        playlistName: entry.value,
        videos: allVideos,
        playlistNames: playlistNames,
      );
      if (error != null) {
        return error;
      }
    }

    if (includeWatchLater) {
      final error = _appendResult(
        result: await exportWatchLater(),
        playlistName: '稍后再看',
        videos: allVideos,
        playlistNames: playlistNames,
      );
      if (error != null) {
        return error;
      }
    }

    if (includeBangumi) {
      final error = _appendResult(
        result: await exportFollowingSeries(type: 1, playlistName: '追番'),
        playlistName: '追番',
        videos: allVideos,
        playlistNames: playlistNames,
      );
      if (error != null) {
        return error;
      }
    }

    if (includeCinema) {
      final error = _appendResult(
        result: await exportFollowingSeries(type: 2, playlistName: '追剧'),
        playlistName: '追剧',
        videos: allVideos,
        playlistNames: playlistNames,
      );
      if (error != null) {
        return error;
      }
    }

    if (playlistNames.isEmpty) {
      return const Error('未选择要导出的播放列表');
    }

    return Success(
      PlaylistExportData(
        exportedAt: DateTime.now(),
        playlistName: playlistNames.join(' + '),
        videos: allVideos,
      ),
    );
  }

  static String exportAsM3U8(PlaylistExportData data) => data.toM3U8();

  static String exportAsJson(PlaylistExportData data) {
    return const JsonEncoder.withIndent('  ').convert(data.toJson());
  }

  static PlaylistVideoItem? _favoriteItemToPlaylist(
    FavDetailItemModel item,
  ) {
    final bvid = item.bvid;
    final favTime = item.favTime;
    final addedAt = favTime == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(favTime * 1000);
    if (bvid != null && bvid.isNotEmpty) {
      return PlaylistVideoItem(
        bvid: bvid,
        title: _titleOrFallback(item.title, bvid),
        cover: item.cover,
        author: item.upper?.name,
        authorMid: item.upper?.mid,
        duration: item.duration,
        addedAt: addedAt,
        description: item.intro,
      );
    }

    final seasonId = item.ogv?.seasonId;
    if (seasonId == null) {
      return null;
    }
    return PlaylistVideoItem(
      itemType: PlaylistItemType.season,
      seasonId: seasonId,
      title: _titleOrFallback(item.title, 'ss$seasonId'),
      cover: item.cover,
      duration: item.duration,
      addedAt: addedAt,
      description: item.intro,
    );
  }

  static PlaylistVideoItem? _watchLaterItemToPlaylist(LaterItemModel item) {
    final bvid = item.bvid;
    if (bvid == null || bvid.isEmpty) {
      return null;
    }
    return PlaylistVideoItem(
      bvid: bvid,
      title: _titleOrFallback(item.title, bvid),
      cover: item.pic,
      author: item.owner?.name,
      authorMid: item.owner?.mid,
      duration: item.duration,
      description: item.subtitle,
    );
  }

  static String _titleOrFallback(String? title, String fallback) {
    final trimmed = title?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }

  static Error? _appendResult({
    required LoadingState<PlaylistExportData> result,
    required String playlistName,
    required List<PlaylistVideoItem> videos,
    required List<String> playlistNames,
  }) {
    if (result case Success(:final response)) {
      videos.addAll(response.videos);
      playlistNames.add(playlistName);
      return null;
    }
    return _errorFrom(result, '导出$playlistName失败');
  }

  static Error _errorFrom<T>(LoadingState<T> result, String fallback) {
    if (result case Error(:final errMsg, :final code)) {
      return Error(errMsg ?? fallback, code: code);
    }
    return Error(fallback);
  }
}
