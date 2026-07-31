import 'dart:convert';
import 'package:pili_plus/http/fav.dart';
import 'package:pili_plus/http/user.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models/playlist_export_data.dart';
import 'package:pili_plus/models_new/fav/fav_detail/data.dart';
import 'package:pili_plus/models_new/later/data.dart';
import 'package:pili_plus/models_new/media_list/media_list.dart';
import 'package:pili_plus/utils/accounts.dart';

enum PlaylistType {
  favorite,
  watchLater,
  seasonFollow,
}

class PlaylistExportService {
  /// Export a favorite list as JSON
  static Future<LoadingState<PlaylistExportData>> exportFavoriteList({
    required int mediaId,
    required String playlistName,
  }) async {
    final allItems = <MediaListItemModel>[];
    int page = 1;
    const pageSize = 50;

    // Fetch all items from the favorite list
    while (true) {
      final result = await FavHttp.userFavFolderDetail(
        mediaId: mediaId,
        pn: page,
        ps: pageSize,
      );

      if (result case Success(:final data)) {
        final items = data.medias ?? [];
        if (items.isEmpty) break;
        allItems.addAll(items);
        if (items.length < pageSize) break;
        page++;
      } else {
        return Error((result as Error).message ?? '获取收藏列表失败');
      }
    }

    final videos = allItems.map((item) => PlaylistVideoItem(
      bvid: item.bvid ?? '',
      title: item.title ?? '',
      cover: item.cover,
      author: item.owner?.name,
      authorMid: item.owner?.mid,
      duration: item.duration,
      addedAt: item.favTime != null
          ? DateTime.fromMillisecondsSinceEpoch(item.favTime! * 1000)
          : null,
      description: item.intro,
    )).toList();

    return Success(PlaylistExportData(
      exportedAt: DateTime.now(),
      playlistName: playlistName,
      videos: videos,
    ));
  }

  /// Export watch later list as JSON
  static Future<LoadingState<PlaylistExportData>> exportWatchLater() async {
    final allItems = <LaterItemModel>[];
    int page = 1;
    const pageSize = 50;

    // Fetch all items from watch later list
    while (true) {
      final result = await UserHttp.seeYouLater(page: page);

      if (result case Success(:final data)) {
        final items = data.items ?? [];
        if (items.isEmpty) break;
        allItems.addAll(items);
        if (items.length < pageSize) break;
        page++;
      } else {
        return Error((result as Error).message ?? '获取稍后再看列表失败');
      }
    }

    final videos = allItems.map((item) => PlaylistVideoItem(
      bvid: item.bvid ?? '',
      title: item.title ?? '',
      cover: item.cover,
      author: item.owner?.name,
      authorMid: item.owner?.mid,
      duration: item.duration,
      addedAt: item.addedAt,
    )).toList();

    return Success(PlaylistExportData(
      exportedAt: DateTime.now(),
      playlistName: '稍后再看',
      videos: videos,
    ));
  }

  /// Export multiple playlists as a combined JSON
  static Future<LoadingState<PlaylistExportData>> exportMultiplePlaylists({
    required Map<int, String> favoriteLists, // mediaId -> name
    required bool includeWatchLater,
  }) async {
    final allVideos = <PlaylistVideoItem>[];
    final playlistNames = <String>[];

    // Export favorite lists
    for (final entry in favoriteLists.entries) {
      final result = await exportFavoriteList(
        mediaId: entry.key,
        playlistName: entry.value,
      );

      if (result case Success(:final data)) {
        allVideos.addAll(data.videos);
        playlistNames.add(entry.value);
      }
    }

    // Export watch later
    if (includeWatchLater) {
      final result = await exportWatchLater();
      if (result case Success(:final data)) {
        allVideos.addAll(data.videos);
        playlistNames.add('稍后再看');
      }
    }

    return Success(PlaylistExportData(
      exportedAt: DateTime.now(),
      playlistName: playlistNames.join(' + '),
      videos: allVideos,
    ));
  }

  /// Export playlist as M3U8 format
  static String exportAsM3U8(PlaylistExportData data) {
    return data.toM3U8();
  }

  /// Export playlist as JSON string
  static String exportAsJson(PlaylistExportData data) {
    return const JsonEncoder.withIndent('  ').convert(data.toJson());
  }
}
