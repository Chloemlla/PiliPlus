/// Typed representation of one Seal download status callback.
final class SealDownloadStatus {
  const SealDownloadStatus({
    required this.status,
    this.protocolVersion = 1,
    this.errorCode,
    this.errorMessage,
    this.taskId,
    this.taskIds = const <String>[],
    this.callerRequestId,
    this.contentUri,
    this.displayName,
    this.mimeType,
    this.stripResult,
    this.stripMessage,
    this.source,
    this.progress,
    this.downloadedBytes,
    this.totalBytes,
    this.title,
    this.quality,
    this.sourceUrl,
    this.extractAudio,
  });

  factory SealDownloadStatus.fromMap(Map<dynamic, dynamic> map) {
    return SealDownloadStatus(
      protocolVersion: _readInt(map['protocol_version']) ?? 1,
      status: map['status']?.toString().trim().toLowerCase() ?? '',
      errorCode: _readString(map['error_code']),
      errorMessage: _readString(map['error_message']),
      taskId: _readString(map['task_id']),
      taskIds: _readStringList(map['task_ids']),
      callerRequestId: _readString(map['caller_request_id']),
      contentUri: _readString(map['content_uri']),
      displayName: _readString(map['display_name']),
      mimeType: _readString(map['mime_type']),
      stripResult: _readString(map['strip_result']),
      stripMessage: _readString(map['strip_message']),
      source: _readString(map['source']),
      progress: _readProgress(map['progress']),
      downloadedBytes: _readNonNegativeInt(map['downloaded_bytes']),
      totalBytes: _readNonNegativeInt(map['total_bytes']),
      title: _readString(map['title']),
      quality: _readString(map['quality']),
      sourceUrl: _readString(map['source_url']),
      extractAudio: _readBool(map['extract_audio']),
    );
  }

  final int protocolVersion;
  final String status;
  final String? errorCode;
  final String? errorMessage;
  final String? taskId;
  final List<String> taskIds;
  final String? callerRequestId;
  final String? contentUri;
  final String? displayName;
  final String? mimeType;
  final String? stripResult;
  final String? stripMessage;

  /// Transport source such as `broadcast` or `activity_result`.
  final String? source;

  /// Download progress in the inclusive 0.0..1.0 range.
  final double? progress;
  final int? downloadedBytes;
  final int? totalBytes;
  final String? title;
  final String? quality;
  final String? sourceUrl;
  final bool? extractAudio;

  /// Queue identity is task-scoped once Seal has assigned a task id.
  String? get stableIdentity => _nonEmpty(taskId) ?? _nonEmpty(callerRequestId);

  bool get isTerminal =>
      status == 'completed' || status == 'failed' || status == 'canceled';

  bool get confirmsAppliedStrip =>
      stripResult?.trim().toLowerCase() == 'applied';

  bool isUnconfirmedCompletedStrip({required bool stripRequested}) =>
      status == 'completed' && stripRequested && !confirmsAppliedStrip;

  String? get stripFailureMessage {
    final message = stripMessage?.trim();
    return message == null || message.isEmpty ? null : message;
  }

  bool get isAudioHint {
    if (extractAudio != null) return extractAudio!;
    final mime = mimeType?.toLowerCase() ?? '';
    final name = displayName?.toLowerCase() ?? '';
    return mime.startsWith('audio/') ||
        name.endsWith('.m4a') ||
        name.endsWith('.mp3') ||
        name.endsWith('.opus') ||
        name.endsWith('.flac');
  }

  bool get isVideoHint {
    if (extractAudio != null) return !extractAudio!;
    final mime = mimeType?.toLowerCase() ?? '';
    final name = displayName?.toLowerCase() ?? '';
    return mime.startsWith('video/') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mkv') ||
        name.endsWith('.webm');
  }

  /// Expand a batch `task_ids` callback into one event per stable task.
  List<SealDownloadStatus> expandTaskIds() {
    final ids = <String>{};
    final primary = _nonEmpty(taskId);
    if (primary != null) ids.add(primary);
    for (final id in taskIds) {
      final normalized = _nonEmpty(id);
      if (normalized != null) ids.add(normalized);
    }
    if (ids.isEmpty) return <SealDownloadStatus>[this];
    return <SealDownloadStatus>[
      for (final id in ids)
        SealDownloadStatus(
          protocolVersion: protocolVersion,
          status: status,
          errorCode: errorCode,
          errorMessage: errorMessage,
          taskId: id,
          callerRequestId: callerRequestId,
          contentUri: contentUri,
          displayName: displayName,
          mimeType: mimeType,
          stripResult: stripResult,
          stripMessage: stripMessage,
          source: source,
          progress: progress,
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes,
          title: title,
          quality: quality,
          sourceUrl: sourceUrl,
          extractAudio: extractAudio,
        ),
    ];
  }

  String? get userFacingErrorMessage {
    final message = errorMessage?.trim();
    if (message != null && message.isNotEmpty) return message;
    final stripFailure = stripResult == 'failed' ? stripFailureMessage : null;
    if (stripFailure != null && stripFailure.isNotEmpty) return stripFailure;
    return switch (errorCode) {
      'disabled' => 'Seal 已关闭外部下载委托',
      'auto_start_denied' => 'Seal 未允许自动开始下载',
      'invalid_url' => '无效的下载链接',
      'invalid_sections' => '去除片段区间无效，请刷新标记后重试',
      'unsupported_version' => 'Seal 协议版本不兼容',
      'caller_denied' => 'Seal 拒绝了当前应用的任务控制请求',
      'task_not_found' => 'Seal 中已找不到该下载任务',
      'unsupported_action' => '当前任务不支持此操作',
      'queue_rejected' => 'Seal 请求过于频繁，请稍后再试',
      'internal_error' => 'Seal 内部错误',
      'download_failed' => 'Seal 下载失败',
      'canceled' => '已取消 Seal 下载',
      'cookie_denied' ||
      'cookies_disabled' => 'Seal 未允许外部 Cookie（请在 Seal → 外部下载中开启）',
      'cookie_invalid' || 'cookies_invalid' => 'Cookie 无效，请重新登录后重试',
      'cookie_too_large' || 'cookies_too_large' => 'Cookie 数据过大',
      'cookies_uri_denied' => '无法将 Cookie 交给 Seal',
      'cookies_unsupported' => 'Seal 不支持当前 Cookie 格式',
      _ => null,
    };
  }
}

String? _readString(Object? value) => _nonEmpty(value?.toString());

String? _nonEmpty(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int? _readInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

int? _readNonNegativeInt(Object? value) {
  final parsed = _readInt(value);
  return parsed?.clamp(0, 1 << 62).toInt();
}

double? _readProgress(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  if (parsed == null || !parsed.isFinite) return null;
  final normalized = parsed > 1 && parsed <= 100 ? parsed / 100 : parsed;
  return normalized.clamp(0.0, 1.0).toDouble();
}

bool? _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch (value?.toString().trim().toLowerCase()) {
    'true' || '1' => true,
    'false' || '0' => false,
    _ => null,
  };
}

List<String> _readStringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  final ids = <String>{};
  for (final item in value) {
    final id = _readString(item);
    if (id != null) ids.add(id);
  }
  return List<String>.unmodifiable(ids);
}
