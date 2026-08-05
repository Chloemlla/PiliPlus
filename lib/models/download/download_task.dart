/// Represents a Seal download task with its current status.
enum DownloadStatus {
  waiting,
  downloading,
  paused,
  completed,
  failed;

  bool get isActive => this == downloading || this == waiting;
  bool get isTerminal => this == completed || this == failed;
}

/// Schema for a download task synced from Seal.
class DownloadTask {
  const DownloadTask({
    required this.requestId,
    required this.bvid,
    required this.title,
    required this.quality,
    required this.format,
    required this.status,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.taskId,
    this.contentUri,
    this.displayName,
    this.source,
    this.extractAudio = false,
  });

  final String requestId;
  final String bvid;
  final String title;
  final String quality;
  final String format;
  final DownloadStatus status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? taskId;
  final String? contentUri;
  final String? displayName;
  final String? source;
  final bool extractAudio;

  String get identity {
    final sealTaskId = taskId?.trim();
    return sealTaskId == null || sealTaskId.isEmpty ? requestId : sealTaskId;
  }

  bool get isAudio => format == 'audio';
  bool get canPause => status.isActive;
  bool get canResume => status == DownloadStatus.paused;
  bool get canRetry => status == DownloadStatus.failed;
  bool get canOpen =>
      status == DownloadStatus.completed && contentUri?.isNotEmpty == true;

  String get formattedSize {
    if (totalBytes <= 0) return '--';
    return '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}';
  }

  String get statusLabel {
    return switch (status) {
      DownloadStatus.waiting => '等待中',
      DownloadStatus.downloading => '下载中',
      DownloadStatus.paused => '已暂停',
      DownloadStatus.completed => '已完成',
      DownloadStatus.failed => '失败',
    };
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final rawRequestId = json['requestId']?.toString().trim() ?? '';
    final rawTaskId = json['taskId']?.toString().trim();
    final requestId = rawRequestId.isNotEmpty ? rawRequestId : rawTaskId ?? '';
    if (requestId.isEmpty) {
      throw const FormatException('Download task identity is missing');
    }
    final statusName = json['status']?.toString();
    final status = DownloadStatus.values.where(
      (value) => value.name == statusName,
    );
    if (status.isEmpty) {
      throw FormatException('Unknown download status: $statusName');
    }
    final createdAt = _readDateTime(json['createdAt']);
    if (createdAt == null) {
      throw const FormatException('Download task createdAt is missing');
    }
    final progress = _readDouble(json['progress']) ?? 0;
    return DownloadTask(
      requestId: requestId,
      bvid: json['bvid']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Seal 下载',
      quality: json['quality']?.toString() ?? '',
      format: json['format']?.toString() == 'audio' ? 'audio' : 'video',
      status: status.first,
      progress: progress.clamp(0.0, 1.0).toDouble(),
      downloadedBytes: _readInt(
        json['downloadedBytes'],
      ).clamp(0, 1 << 62).toInt(),
      totalBytes: _readInt(json['totalBytes']).clamp(0, 1 << 62).toInt(),
      errorMessage: _readNullableString(json['errorMessage']),
      createdAt: createdAt,
      completedAt: _readDateTime(json['completedAt']),
      taskId: _readNullableString(json['taskId']),
      contentUri: _readNullableString(json['contentUri']),
      displayName: _readNullableString(json['displayName']),
      source: _readNullableString(json['source']),
      extractAudio: _readBool(json['extractAudio']) ?? false,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'requestId': requestId,
    'bvid': bvid,
    'title': title,
    'quality': quality,
    'format': format,
    'status': status.name,
    'progress': progress,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'errorMessage': errorMessage,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'completedAt': completedAt?.millisecondsSinceEpoch,
    'taskId': taskId,
    'contentUri': contentUri,
    'displayName': displayName,
    'source': source,
    'extractAudio': extractAudio,
  };

  DownloadTask copyWith({
    String? requestId,
    String? bvid,
    String? title,
    String? quality,
    String? format,
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    Object? errorMessage = _unsetDownloadTaskField,
    DateTime? createdAt,
    Object? completedAt = _unsetDownloadTaskField,
    Object? taskId = _unsetDownloadTaskField,
    Object? contentUri = _unsetDownloadTaskField,
    Object? displayName = _unsetDownloadTaskField,
    Object? source = _unsetDownloadTaskField,
    bool? extractAudio,
  }) {
    return DownloadTask(
      requestId: requestId ?? this.requestId,
      bvid: bvid ?? this.bvid,
      title: title ?? this.title,
      quality: quality ?? this.quality,
      format: format ?? this.format,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: identical(errorMessage, _unsetDownloadTaskField)
          ? this.errorMessage
          : errorMessage as String?,
      createdAt: createdAt ?? this.createdAt,
      completedAt: identical(completedAt, _unsetDownloadTaskField)
          ? this.completedAt
          : completedAt as DateTime?,
      taskId: identical(taskId, _unsetDownloadTaskField)
          ? this.taskId
          : taskId as String?,
      contentUri: identical(contentUri, _unsetDownloadTaskField)
          ? this.contentUri
          : contentUri as String?,
      displayName: identical(displayName, _unsetDownloadTaskField)
          ? this.displayName
          : displayName as String?,
      source: identical(source, _unsetDownloadTaskField)
          ? this.source
          : source as String?,
      extractAudio: extractAudio ?? this.extractAudio,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DownloadTask && other.identity == identity;
  }

  @override
  int get hashCode => identity.hashCode;
}

const Object _unsetDownloadTaskField = Object();

int _readInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool? _readBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return switch (value?.toString().toLowerCase()) {
    'true' || '1' => true,
    'false' || '0' => false,
    _ => null,
  };
}

DateTime? _readDateTime(Object? value) {
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  final epoch = int.tryParse(text);
  return epoch != null
      ? DateTime.fromMillisecondsSinceEpoch(epoch)
      : DateTime.tryParse(text);
}

String? _readNullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
