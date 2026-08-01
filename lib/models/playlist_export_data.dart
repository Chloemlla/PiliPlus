enum PlaylistItemType {
  video,
  season,
}

/// A portable playlist entry.
///
/// Video entries use [bvid]. Following-series backups use [seasonId] because
/// the Bilibili following API exposes seasons rather than individual videos.
class PlaylistVideoItem {
  final PlaylistItemType itemType;
  final String? bvid;
  final int? seasonId;
  final String title;
  final String? cover;
  final String? author;
  final int? authorMid;
  final int? duration;
  final DateTime? addedAt;
  final String? description;

  const PlaylistVideoItem({
    this.itemType = PlaylistItemType.video,
    this.bvid,
    this.seasonId,
    required this.title,
    this.cover,
    this.author,
    this.authorMid,
    this.duration,
    this.addedAt,
    this.description,
  });

  bool get isVideo => itemType == PlaylistItemType.video && bvid != null;

  bool get isSeason => itemType == PlaylistItemType.season && seasonId != null;

  String get referenceLabel => switch (itemType) {
    PlaylistItemType.video => bvid ?? '',
    PlaylistItemType.season => seasonId == null ? '' : 'ss$seasonId',
  };

  String? get referenceUrl => switch (itemType) {
    PlaylistItemType.video when bvid != null =>
      'https://www.bilibili.com/video/$bvid',
    PlaylistItemType.season when seasonId != null =>
      'https://www.bilibili.com/bangumi/play/ss$seasonId',
    _ => null,
  };

  Map<String, dynamic> toJson() {
    return {
      'itemType': itemType.name,
      'bvid': bvid,
      'seasonId': seasonId,
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
    final itemType = switch (json['itemType']) {
      null || 'video' => PlaylistItemType.video,
      'season' => PlaylistItemType.season,
      final Object value => throw FormatException('不支持的条目类型: $value'),
    };
    final title = _requiredString(json, 'title');
    final bvid = _optionalString(json, 'bvid');
    final seasonId = _optionalInt(json, 'seasonId');
    final duration = _optionalInt(json, 'duration');

    if (itemType == PlaylistItemType.video && bvid == null) {
      throw const FormatException('视频条目缺少 bvid');
    }
    if (itemType == PlaylistItemType.season && seasonId == null) {
      throw const FormatException('追番/追剧条目缺少 seasonId');
    }
    if (seasonId != null && seasonId <= 0) {
      throw const FormatException('seasonId 必须为正整数');
    }
    if (duration != null && duration < 0) {
      throw const FormatException('duration 不能为负数');
    }

    final addedAtValue = _optionalString(json, 'addedAt');
    final addedAt = addedAtValue == null
        ? null
        : DateTime.tryParse(addedAtValue);
    if (addedAtValue != null && addedAt == null) {
      throw const FormatException('addedAt 不是有效的日期时间');
    }

    return PlaylistVideoItem(
      itemType: itemType,
      bvid: bvid,
      seasonId: seasonId,
      title: title,
      cover: _optionalString(json, 'cover'),
      author: _optionalString(json, 'author'),
      authorMid: _optionalInt(json, 'authorMid'),
      duration: duration,
      addedAt: addedAt,
      description: _optionalString(json, 'description'),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    throw FormatException('$key 缺失或格式无效');
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value.isEmpty ? null : value;
    }
    throw FormatException('$key 格式无效');
  }

  static int? _optionalInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    throw FormatException('$key 格式无效');
  }
}

/// Portable PiliPlus playlist data (schema version 1).
class PlaylistExportData {
  static const int currentVersion = 1;
  static const String appName = 'PiliPlus';

  final int version;
  final String app;
  final DateTime exportedAt;
  final String playlistName;
  final int count;
  final List<PlaylistVideoItem> videos;

  PlaylistExportData({
    this.version = currentVersion,
    this.app = appName,
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
      'videos': videos.map((video) => video.toJson()).toList(),
    };
  }

  factory PlaylistExportData.fromJson(Map<String, dynamic> json) {
    final versionValue = json['version'];
    final appValue = json['app'];
    final exportedAtValue = json['exportedAt'];
    final playlistNameValue = json['playlistName'];
    final countValue = json['count'];
    final videosValue = json['videos'];

    if (versionValue is! int || versionValue != currentVersion) {
      throw FormatException('不支持的播放列表版本: $versionValue');
    }
    if (appValue != appName) {
      throw const FormatException('无效的播放列表来源');
    }
    if (exportedAtValue is! String) {
      throw const FormatException('缺少导出时间');
    }
    final exportedAt = DateTime.tryParse(exportedAtValue);
    if (exportedAt == null) {
      throw const FormatException('导出时间格式无效');
    }
    if (playlistNameValue is! String || playlistNameValue.trim().isEmpty) {
      throw const FormatException('缺少播放列表名称');
    }
    if (countValue is! int || countValue < 0) {
      throw const FormatException('视频数量格式无效');
    }
    if (videosValue is! List) {
      throw const FormatException('缺少视频列表');
    }

    final videos = <PlaylistVideoItem>[];
    for (final (index, value) in videosValue.indexed) {
      if (value is! Map) {
        throw FormatException('第 ${index + 1} 个条目格式无效');
      }
      try {
        videos.add(
          PlaylistVideoItem.fromJson(Map<String, dynamic>.from(value)),
        );
      } on FormatException catch (error) {
        throw FormatException('第 ${index + 1} 个条目无效: ${error.message}');
      }
    }

    if (countValue != videos.length) {
      throw FormatException(
        '视频数量不一致: 声明 $countValue，实际 ${videos.length}',
      );
    }

    return PlaylistExportData(
      version: versionValue,
      app: appValue as String,
      exportedAt: exportedAt,
      playlistName: playlistNameValue,
      videos: videos,
    );
  }

  /// Converts this backup to an M3U8 reference playlist.
  ///
  /// Bilibili media URLs are short-lived, so stable video/season page URLs are
  /// emitted together with custom reference tags instead of expiring streams.
  String toM3U8() {
    final lines = <String>[
      '#EXTM3U',
      '# Playlist exported by PiliPlus',
      '# Direct Bilibili media URLs expire; stable page references follow.',
      '# Exported at: ${exportedAt.toIso8601String()}',
      '# Count: $count entries',
      '#EXTPLIST:${_escapeM3U8Text(playlistName)}',
    ];

    for (final video in videos) {
      lines.addAll([
        '#EXTINF:${video.duration ?? 0},${_escapeM3U8Text(video.title)}',
        switch (video.itemType) {
          PlaylistItemType.video => '#EXTV-BVID:${video.bvid}',
          PlaylistItemType.season => '#EXTV-SEASON-ID:${video.seasonId}',
        },
        if (video.author case final author?)
          '#EXTV-AUTHOR:${_escapeM3U8Text(author)}',
        if (video.cover case final cover?)
          '#EXTV-COVER:${_escapeM3U8Text(cover)}',
        ?video.referenceUrl,
      ]);
    }

    lines.add('#EXT-X-ENDLIST');
    return '${lines.join('\n')}\n';
  }

  static String _escapeM3U8Text(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r');
  }

  String get previewInfo => '$playlistName ($count 个条目)';
}

class PlaylistImportResult {
  final int totalCount;
  final int importedCount;
  final int duplicateCount;
  final int unsupportedCount;
  final int failedCount;
  final List<String> duplicateBvids;
  final List<String> failedBvids;

  const PlaylistImportResult({
    required this.totalCount,
    required this.importedCount,
    required this.duplicateCount,
    required this.unsupportedCount,
    required this.failedCount,
    required this.duplicateBvids,
    required this.failedBvids,
  });

  int get skippedCount => duplicateCount + unsupportedCount + failedCount;

  String get summary {
    if (totalCount == 0) {
      return '播放列表中没有可导入的条目';
    }
    if (skippedCount == 0) {
      return '成功导入 $importedCount 个视频';
    }

    final parts = <String>[
      '已导入 $importedCount 个视频',
      if (duplicateCount > 0) '已跳过 $duplicateCount 个重复',
      if (unsupportedCount > 0) '忽略 $unsupportedCount 个追番/追剧条目',
      if (failedCount > 0) '$failedCount 个导入失败',
    ];
    return parts.join('，');
  }
}
