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

  bool get isAudio => format == 'audio';
  bool get canPause => status == downloading || status == waiting;
  bool get canResume => status == paused;
  bool get canRetry => status == failed;
  bool get canOpen => status == completed && contentUri?.isNotEmpty == true;

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
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
    String? taskId,
    String? contentUri,
    String? displayName,
    String? source,
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
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      taskId: taskId ?? this.taskId,
      contentUri: contentUri ?? this.contentUri,
      displayName: displayName ?? this.displayName,
      source: source ?? this.source,
      extractAudio: extractAudio ?? this.extractAudio,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DownloadTask && other.requestId == requestId;
  }

  @override
  int get hashCode => requestId.hashCode;
}
