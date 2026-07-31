import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/download/download_task.dart';
import 'package:pili_plus/pages/video/seal_download_utils.dart';
import 'package:pili_plus/utils/page_utils.dart';

/// Service that bridges Seal download status to PiliPlus.
///
/// Syncs download tasks from Seal broadcasts and exposes reactive state.
class DownloadManagerService extends GetxService {
  static const _channel = MethodChannel('pili_plus/seal_download');
  static const releasesUrl = 'https://github.com/Chloemlla/Seal/releases';

  /// All known download tasks.
  final tasks = <DownloadTask>[].obs;

  /// Currently selected task ids for batch operations.
  final selectedIds = <String>{}.obs;

  /// Whether multi-select mode is active.
  final isSelectionMode = false.obs;

  /// Stats: completed, downloading, waiting, failed counts.
  final stats = DownloadStats.empty().obs;

  /// Whether Seal is installed.
  final isSealInstalled = true.obs;

  bool _listening = false;

  @override
  void onInit() {
    super.onInit();
    _ensureListening();
  }

  void _ensureListening() {
    if (!Platform.isAndroid || _listening) return;
    _listening = true;
    _channel.setMethodCallHandler(_onMethodCall);
    _channel.invokeMethod<void>('readyForStatus').catchError((Object _) {});
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != 'onDownloadStatus') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final status = SealDownloadStatus.fromMap(args);
    _handleStatusEvent(status);
    return null;
  }

  void _handleStatusEvent(SealDownloadStatus status) {
    if (kDebugMode) {
      debugPrint(
        'DownloadManager received: ${status.status} '
        'task=${status.taskId} req=${status.callerRequestId}',
      );
    }

    final requestId = status.callerRequestId;
    if (requestId == null || requestId.isEmpty) return;

    final existingIndex = tasks.indexWhere((t) => t.requestId == requestId);
    final newStatus = _mapSealStatus(status);

    if (newStatus == null) return;

    if (existingIndex >= 0) {
      // Update existing task
      final existing = tasks[existingIndex];
      final updated = _mergeTaskUpdate(existing, status, newStatus);
      tasks[existingIndex] = updated;
    } else {
      // New task
      final task = _createTaskFromStatus(requestId, status, newStatus);
      tasks.insert(0, task);
    }

    _refreshStats();
  }

  DownloadStatus? _mapSealStatus(SealDownloadStatus status) {
    return switch (status.status) {
      'waiting' || 'queued' => DownloadStatus.waiting,
      'downloading' || 'accepted' || 'progress' => DownloadStatus.downloading,
      'paused' => DownloadStatus.paused,
      'completed' => DownloadStatus.completed,
      'failed' || 'error' => DownloadStatus.failed,
      'canceled' || 'rejected' => null,
      _ => null,
    };
  }

  DownloadTask _createTaskFromStatus(
    String requestId,
    SealDownloadStatus status,
    DownloadStatus mappedStatus,
  ) {
    return DownloadTask(
      requestId: requestId,
      bvid: _extractBvid(status.source),
      title: status.displayName ?? 'Seal 下载',
      quality: '',
      format: status.isAudioHint ? 'audio' : 'video',
      status: mappedStatus,
      progress: _extractProgress(status),
      downloadedBytes: 0,
      totalBytes: 0,
      errorMessage: status.userFacingErrorMessage,
      createdAt: DateTime.now(),
      completedAt: mappedStatus == DownloadStatus.completed ? DateTime.now() : null,
      taskId: status.taskId,
      contentUri: status.contentUri,
      displayName: status.displayName,
      source: status.source,
      extractAudio: status.isAudioHint,
    );
  }

  DownloadTask _mergeTaskUpdate(
    DownloadTask existing,
    SealDownloadStatus status,
    DownloadStatus newStatus,
  ) {
    final progress = _extractProgress(status);
    return existing.copyWith(
      status: newStatus,
      progress: progress,
      downloadedBytes: _extractDownloadedBytes(status),
      totalBytes: _extractTotalBytes(status),
      errorMessage: status.userFacingErrorMessage,
      completedAt: newStatus == DownloadStatus.completed ? DateTime.now() : null,
      contentUri: status.contentUri ?? existing.contentUri,
      displayName: status.displayName ?? existing.displayName,
    );
  }

  double _extractProgress(SealDownloadStatus status) {
    // Seal may send progress via custom data; default to deterministic values
    return switch (status.status) {
      'completed' => 1.0,
      'downloading' || 'progress' => 0.5, // Placeholder until real progress
      _ => 0.0,
    };
  }

  int _extractDownloadedBytes(SealDownloadStatus status) {
    return 0; // Placeholder
  }

  int _extractTotalBytes(SealDownloadStatus status) {
    return 0; // Placeholder
  }

  String _extractBvid(String? source) {
    if (source == null || source.isEmpty) return '';
    // Try to extract bvid from URL pattern
    final match = RegExp(r'BV\w+').firstMatch(source);
    return match?.group(0) ?? '';
  }

  void _refreshStats() {
    int completed = 0;
    int downloading = 0;
    int waiting = 0;
    int failed = 0;
    int totalBytes = 0;

    for (final task in tasks) {
      switch (task.status) {
        case DownloadStatus.completed:
          completed++;
          totalBytes += task.totalBytes;
        case DownloadStatus.downloading:
          downloading++;
          totalBytes += task.downloadedBytes;
        case DownloadStatus.waiting:
          waiting++;
        case DownloadStatus.failed:
          failed++;
        case DownloadStatus.paused:
          totalBytes += task.totalBytes;
      }
    }

    stats.value = DownloadStats(
      total: tasks.length,
      completed: completed,
      downloading: downloading,
      waiting: waiting,
      failed: failed,
      totalBytes: totalBytes,
    );
  }

  /// Enter multi-select mode.
  void enterSelectionMode() {
    isSelectionMode.value = true;
    selectedIds.clear();
  }

  /// Exit multi-select mode.
  void exitSelectionMode() {
    isSelectionMode.value = false;
    selectedIds.clear();
  }

  /// Toggle selection of a task.
  void toggleSelection(String requestId) {
    if (selectedIds.contains(requestId)) {
      selectedIds.remove(requestId);
    } else {
      selectedIds.add(requestId);
    }
  }

  /// Select all tasks.
  void selectAll() {
    selectedIds.addAll(tasks.map((t) => t.requestId));
  }

  /// Deselect all tasks.
  void deselectAll() {
    selectedIds.clear();
  }

  /// Get selected tasks.
  List<DownloadTask> get selectedTasks {
    return tasks.where((t) => selectedIds.contains(t.requestId)).toList();
  }

  /// Pause a task.
  Future<void> pauseTask(DownloadTask task) async {
    if (!task.canPause) return;
    await _sendTaskAction(task, 'pause');
    _updateTaskStatus(task.requestId, DownloadStatus.paused);
  }

  /// Resume a task.
  Future<void> resumeTask(DownloadTask task) async {
    if (!task.canResume) return;
    await _sendTaskAction(task, 'resume');
    _updateTaskStatus(task.requestId, DownloadStatus.downloading);
  }

  /// Retry a failed task.
  Future<void> retryTask(DownloadTask task) async {
    if (!task.canRetry) return;
    await _sendTaskAction(task, 'retry');
    _updateTaskStatus(task.requestId, DownloadStatus.waiting);
  }

  /// Delete a task.
  Future<void> deleteTask(DownloadTask task) async {
    await _sendTaskAction(task, 'delete');
    tasks.removeWhere((t) => t.requestId == task.requestId);
    selectedIds.remove(task.requestId);
    _refreshStats();
  }

  /// Open completed task file.
  Future<void> openTask(DownloadTask task) async {
    if (!task.canOpen || task.contentUri == null) return;
    await SealDownloadUtils.openContentUri(
      uri: task.contentUri!,
      mimeType: task.isAudio ? 'audio/*' : 'video/*',
    );
  }

  /// Share completed task.
  Future<void> shareTask(DownloadTask task) async {
    if (!task.canOpen || task.contentUri == null) return;
    await SealDownloadUtils.shareContentUri(
      uri: task.contentUri!,
      mimeType: task.isAudio ? 'audio/*' : 'video/*',
      displayName: task.displayName,
    );
  }

  /// Batch pause selected tasks.
  Future<void> pauseSelected() async {
    for (final task in selectedTasks) {
      await pauseTask(task);
    }
  }

  /// Batch resume selected tasks.
  Future<void> resumeSelected() async {
    for (final task in selectedTasks) {
      await resumeTask(task);
    }
  }

  /// Batch delete selected tasks.
  Future<void> deleteSelected() async {
    for (final task in selectedTasks.toList()) {
      await deleteTask(task);
    }
    exitSelectionMode();
  }

  /// Batch retry failed selected tasks.
  Future<void> retryFailedSelected() async {
    for (final task in selectedTasks.where((t) => t.status == DownloadStatus.failed)) {
      await retryTask(task);
    }
  }

  Future<void> _sendTaskAction(DownloadTask task, String action) async {
    try {
      await _channel.invokeMethod<void>('taskAction', {
        'requestId': task.requestId,
        'taskId': task.taskId,
        'action': action,
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to send task action $action: ${e.message}');
      }
    }
  }

  void _updateTaskStatus(String requestId, DownloadStatus newStatus) {
    final index = tasks.indexWhere((t) => t.requestId == requestId);
    if (index >= 0) {
      tasks[index] = tasks[index].copyWith(status: newStatus);
      _refreshStats();
    }
  }

  /// Open Seal releases page.
  Future<void> openSealReleases() async {
    await PageUtils.launchURL(releasesUrl);
  }
}

class DownloadStats {
  const DownloadStats({
    required this.total,
    required this.completed,
    required this.downloading,
    required this.waiting,
    required this.failed,
    required this.totalBytes,
  });

  factory DownloadStats.empty() => const DownloadStats(
        total: 0,
        completed: 0,
        downloading: 0,
        waiting: 0,
        failed: 0,
        totalBytes: 0,
      );

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
