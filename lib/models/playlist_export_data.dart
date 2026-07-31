/// Represents a video item in a playlist for import/export
class PlaylistVideoItem {
  final String bvid;
  final String title;
  final String? cover;
  final String? author;
  final int? authorMid;
  final int? duration;
  final DateTime? addedAt;
  final String? description;

  PlaylistVideoItem({
    required this.bvid,
    required this.title,
    this.cover,
    this.author,
    this.authorMid,
    this.duration,
    this.addedAt,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'bvid': bvid,
      'title': title,
      'cover': cover,
      'author': author,
      'authorMid': authorMid,
      'duration': duration,
      'addedAt': addedAt?.toIso8601String(),
      'description': description,
    };
  }

  factory PlaylistVideoItem.fromJson(Map<String, dynamic> json) {
    return PlaylistVideoItem(
      bvid: json['bvid'] as String,
      title: json['title'] as String,
      cover: json['cover'] as String?,
      author: json['author'] as String?,
      authorMid: json['authorMid'] as int?,
      duration: json['duration'] as int?,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'] as String)
          : null,
      description: json['description'] as String?,
    );
  }
}

/// Represents a playlist for import/export
class PlaylistExportData {
  final int version;
  final String app;
  final DateTime exportedAt;
  final String playlistName;
  final int count;
  final List<PlaylistVideoItem> videos;

  PlaylistExportData({
    this.version = 1,
    this.app = 'PiliPlus',
    required this.exportedAt,
    required this.playlistName,
    required this.videos,
  }) : count = videos.length;

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'app': app,
      'exportedAt': exportedAt.toIso8601String(),
      'playlistName': playlistName,
      'count': count,
      'videos': videos.map((v) => v.toJson()).toList(),
    };
  }

  factory PlaylistExportData.fromJson(Map<String, dynamic> json) {
    final videosList = (json['videos'] as List)
        .map((v) => PlaylistVideoItem.fromJson(v as Map<String, dynamic>))
        .toList();

    return PlaylistExportData(
      version: json['version'] as int? ?? 1,
      app: json['app'] as String? ?? 'PiliPlus',
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      playlistName: json['playlistName'] as String,
      videos: videosList,
    );
  }

  /// Convert to m3u8 format string
  String toM3U8() {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('# PlayList exported by PiliPlus');
    buffer.writeln('# Exported at: ${exportedAt.toIso8601String()}');
    buffer.writeln('# Count: $count videos');
    buffer.writeln('#EXTPLIST:$playlistName');

    for (final video in videos) {
      final duration = video.duration ?? 0;
      final title = _escapeM3U8Text(video.title);
      buffer.writeln('#EXTINF:$duration,$title');
      // Note: Direct URL cannot be resolved client-side for Bilibili videos
      // Use bvid reference format
      buffer.writeln('#EXTV-BVID:${video.bvid}');
      if (video.author != null) {
        buffer.writeln('#EXTV-AUTHOR:${_escapeM3U8Text(video.author!)}');
      }
      if (video.cover != null) {
        buffer.writeln('#EXTV-COVER:${_escapeM3U8Text(video.cover!)}');
      }
    }

    buffer.writeln('#EXT-X-ENDLIST');
    return buffer.toString();
  }

  String _escapeM3U8Text(String text) {
    // Escape characters that are not allowed in m3u8
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  /// Get preview info for import dialog
  String get previewInfo {
    return '$playlistName ($count 个视频)';
  }
}

/// Result of playlist import operation
class PlaylistImportResult {
  final int totalCount;
  final int importedCount;
  final int skippedCount;
  final List<String> skippedBvids;

  PlaylistImportResult({
    required this.totalCount,
    required this.importedCount,
    required this.skippedCount,
    required this.skippedBvids,
  });

  String get summary {
    if (skippedCount == 0) {
      return '成功导入 $importedCount 个视频';
    }
    return '已导入 $importedCount 个视频，跳过 $skippedCount 个重复';
  }
}
