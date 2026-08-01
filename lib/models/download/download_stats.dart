final class DownloadStats {
  const DownloadStats({
    required this.total,
    required this.completed,
    required this.downloading,
    required this.waiting,
    required this.failed,
    required this.totalBytes,
  });

  const DownloadStats.empty()
    : total = 0,
      completed = 0,
      downloading = 0,
      waiting = 0,
      failed = 0,
      totalBytes = 0;

  final int total;
  final int completed;
  final int downloading;
  final int waiting;
  final int failed;
  final int totalBytes;

  String get formattedStorageUsed {
    final bytes = totalBytes;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
