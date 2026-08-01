import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/download/download_stats.dart';
import 'package:pili_plus/models/download/download_task.dart';
import 'package:pili_plus/models/download/seal_download_status.dart';
import 'package:pili_plus/services/crash/crash_context.dart';
import 'package:pili_plus/services/crash/crash_reporter.dart';
import 'package:pili_plus/services/download_task_repository.dart';
import 'package:pili_plus/services/seal_download_channel_dispatcher.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:pili_plus/utils/persistence.dart';

typedef DownloadManagerErrorReporter =
    void Function(
      Object error,
      StackTrace stackTrace, {
      required String operation,
    });

/// Syncs Seal task broadcasts into a persisted, reactive task list.
class DownloadManagerService extends GetxService {
  DownloadManagerService({
    DownloadTaskRepository? repository,
    SealDownloadChannelDispatcher? channel,
    DownloadManagerErrorReporter? errorReporter,
  }) : _repository = repository ?? DownloadTaskRepository(),
       _channel = channel ?? SealDownloadChannelDispatcher.instance,
       _errorReporter = errorReporter ?? _recordDownloadManagerError;

  static const releasesUrl = 'https://github.com/Chloemlla/Seal/releases';

  final DownloadTaskRepository _repository;
  final SealDownloadChannelDispatcher _channel;
  final DownloadManagerErrorReporter _errorReporter;

  final tasks = <DownloadTask>[].obs;
  final selectedIds = <String>{}.obs;
  final isSelectionMode = false.obs;
  final stats = (const DownloadStats.empty()).obs;
  final isSealInstalled = Platform.isAndroid.obs;

  Future<void>? _initialization;
  bool _listenerRegistered = false;

  @override
  void onInit() {
    super.onInit();
    unawaited(initialize());
  }

  @override
  void onClose() {
    if (_listenerRegistered) {
      _channel.removeStatusListener(_handleStatusEvent);
      _listenerRegistered = false;
    }
    super.onClose();
  }

  /// Restores bounded history before asking the native bridge for queued events.
  ///
  /// Download management is optional at startup. Initialization failures are
  /// recorded as handled diagnostics and never abort the rest of app startup.
  Future<void> initialize() => _initialization ??= _initializeSafely();

  Future<void> _initializeSafely() async {
    try {
      await _initialize();
    } catch (error, stackTrace) {
      _reportHandledError(
        error,
        stackTrace,
        operation: 'DownloadManagerService.initialize',
      );
    }
  }

  Future<void> _initialize() async {
    _registerStatusListener();
    try {
      final restored = await _repository.load();
      _mergeRestoredTasks(restored);
    } catch (error, stackTrace) {
      _reportHandledError(
        error,
        stackTrace,
        operation: 'DownloadManagerService.restoreHistory',
      );
    }
    _refreshStats();
    await refreshStatus();
  }

  void _registerStatusListener() {
    if (_listenerRegistered || !Platform.isAndroid) return;
    _listenerRegistered = true;
    _channel.addStatusListener(_handleStatusEvent);
  }

  void _mergeRestoredTasks(Iterable<DownloadTask> restored) {
    final liveIdentities = tasks.map((task) => task.identity).toSet();
    for (final task in restored) {
      if (liveIdentities.add(task.identity)) tasks.add(task);
    }
    tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Refresh Seal availability and flush Application-scoped native events.
  Future<void> refreshStatus() async {
    if (!Platform.isAndroid) {
      isSealInstalled.value = false;
      return;
    }
    try {
      isSealInstalled.value =
          await _channel.invokeMethod<bool>('isInstalled') ?? false;
      if (isSealInstalled.value) {
        await _channel.invokeMethod<void>('readyForStatus');
      }
    } on PlatformException catch (error, stackTrace) {
      isSealInstalled.value = false;
      if (kDebugMode) {
        debugPrint('Failed to refresh Seal state: ${error.message}');
      }
      _reportHandledError(
        error,
        stackTrace,
        operation: 'DownloadManagerService.refreshStatus',
      );
    } on MissingPluginException catch (error, stackTrace) {
      isSealInstalled.value = false;
      if (kDebugMode) debugPrint('Seal channel is unavailable: $error');
      _reportHandledError(
        error,
        stackTrace,
        operation: 'DownloadManagerService.refreshStatus',
      );
    } catch (error, stackTrace) {
      isSealInstalled.value = false;
      _reportHandledError(
        error,
        stackTrace,
        operation: 'DownloadManagerService.refreshStatus',
      );
    }
  }

  void _reportHandledError(
    Object error,
    StackTrace stackTrace, {
    required String operation,
  }) {
    try {
      _errorReporter(error, stackTrace, operation: operation);
    } catch (reportingError) {
      if (kDebugMode) {
        debugPrint(
          'Download manager error reporting failed: $reportingError',
        );
      }
    }
  }

  Future<void> _handleStatusEvent(SealDownloadStatus status) async {
    var changed = false;
    for (final taskStatus in status.expandTaskIds()) {
      changed = _applyStatus(taskStatus) || changed;
    }
    if (!changed) return;
    _refreshStats();
    _persistTasks();
  }

  bool _applyStatus(SealDownloadStatus status) {
    final identity = status.stableIdentity;
    if (identity == null) return false;

    if (status.status == 'canceled') {
      final previousLength = tasks.length;
      tasks.removeWhere((task) => task.identity == identity);
      selectedIds.remove(identity);
      return tasks.length != previousLength;
    }

    final mappedStatus = _mapSealStatus(status.status);
    if (mappedStatus == null) return false;
    final existingIndex = _findTaskIndex(status);
    if (existingIndex >= 0) {
      tasks[existingIndex] = _mergeTaskUpdate(
        tasks[existingIndex],
        status,
        mappedStatus,
      );
    } else {
      tasks.insert(0, _createTaskFromStatus(status, mappedStatus));
    }
    return true;
  }

  int _findTaskIndex(SealDownloadStatus status) {
    final taskId = status.taskId?.trim();
    if (taskId != null && taskId.isNotEmpty) {
      final exact = tasks.indexWhere((task) => task.taskId == taskId);
      if (exact >= 0) return exact;
    }
    final requestId = status.callerRequestId?.trim();
    if (requestId == null || requestId.isEmpty) return -1;
    return tasks.indexWhere(
      (task) =>
          task.requestId == requestId &&
          (task.taskId == null || task.taskId!.isEmpty),
    );
  }

  DownloadStatus? _mapSealStatus(String status) {
    return switch (status) {
      'waiting' || 'queued' || 'accepted' => DownloadStatus.waiting,
      'fetching' || 'downloading' || 'progress' => DownloadStatus.downloading,
      'paused' => DownloadStatus.paused,
      'completed' => DownloadStatus.completed,
      'failed' || 'error' => DownloadStatus.failed,
      _ => null,
    };
  }

  DownloadTask _createTaskFromStatus(
    SealDownloadStatus status,
    DownloadStatus mappedStatus,
  ) {
    final identity = status.stableIdentity!;
    final requestId = _nonEmpty(status.callerRequestId) ?? identity;
    final totalBytes = status.totalBytes ?? 0;
    final downloadedBytes =
        status.downloadedBytes ??
        (mappedStatus == DownloadStatus.completed ? totalBytes : 0);
    final sourceUrl = status.sourceUrl;
    return DownloadTask(
      requestId: requestId,
      bvid: _extractBvid(sourceUrl),
      title:
          _nonEmpty(status.title) ?? _nonEmpty(status.displayName) ?? 'Seal 下载',
      quality: status.quality ?? '',
      format: status.isAudioHint ? 'audio' : 'video',
      status: mappedStatus,
      progress:
          status.progress ??
          (mappedStatus == DownloadStatus.completed ? 1.0 : 0.0),
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      errorMessage: mappedStatus == DownloadStatus.failed
          ? status.userFacingErrorMessage
          : null,
      createdAt: DateTime.now(),
      completedAt: mappedStatus == DownloadStatus.completed
          ? DateTime.now()
          : null,
      taskId: status.taskId,
      contentUri: status.contentUri,
      displayName: status.displayName,
      source: sourceUrl,
      extractAudio: status.extractAudio ?? status.isAudioHint,
    );
  }

  DownloadTask _mergeTaskUpdate(
    DownloadTask existing,
    SealDownloadStatus status,
    DownloadStatus newStatus,
  ) {
    final totalBytes = status.totalBytes ?? existing.totalBytes;
    final downloadedBytes =
        status.downloadedBytes ??
        (newStatus == DownloadStatus.completed
            ? totalBytes
            : existing.downloadedBytes);
    final sourceUrl = _nonEmpty(status.sourceUrl) ?? existing.source;
    return existing.copyWith(
      bvid: _extractBvid(sourceUrl).isEmpty
          ? existing.bvid
          : _extractBvid(sourceUrl),
      title:
          _nonEmpty(status.title) ??
          _nonEmpty(status.displayName) ??
          existing.title,
      quality: _nonEmpty(status.quality) ?? existing.quality,
      format: status.extractAudio == null
          ? existing.format
          : (status.extractAudio! ? 'audio' : 'video'),
      status: newStatus,
      progress:
          status.progress ??
          (newStatus == DownloadStatus.completed ? 1.0 : existing.progress),
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      errorMessage: newStatus == DownloadStatus.failed
          ? status.userFacingErrorMessage
          : null,
      completedAt: newStatus == DownloadStatus.completed
          ? existing.completedAt ?? DateTime.now()
          : null,
      taskId: status.taskId ?? existing.taskId,
      contentUri: status.contentUri ?? existing.contentUri,
      displayName: status.displayName ?? existing.displayName,
      source: sourceUrl,
      extractAudio: status.extractAudio ?? existing.extractAudio,
    );
  }

  String _extractBvid(String? sourceUrl) {
    if (sourceUrl == null || sourceUrl.isEmpty) return '';
    return RegExp(r'BV\w+').firstMatch(sourceUrl)?.group(0) ?? '';
  }

  void _refreshStats() {
    var completed = 0;
    var downloading = 0;
    var waiting = 0;
    var failed = 0;
    var downloadedBytes = 0;
    for (final task in tasks) {
      downloadedBytes += task.downloadedBytes;
      switch (task.status) {
        case DownloadStatus.completed:
          completed++;
        case DownloadStatus.downloading:
          downloading++;
        case DownloadStatus.waiting:
          waiting++;
        case DownloadStatus.failed:
          failed++;
        case DownloadStatus.paused:
          break;
      }
    }
    stats.value = DownloadStats(
      total: tasks.length,
      completed: completed,
      downloading: downloading,
      waiting: waiting,
      failed: failed,
      totalBytes: downloadedBytes,
    );
  }

  void _persistTasks() {
    Persistence.background(
      _repository.replaceAll(tasks),
      label: 'seal_download_task_history',
    );
  }

  void enterSelectionMode() {
    isSelectionMode.value = true;
    selectedIds.clear();
  }

  void exitSelectionMode() {
    isSelectionMode.value = false;
    selectedIds.clear();
  }

  void toggleSelection(String taskIdentity) {
    if (!selectedIds.remove(taskIdentity)) selectedIds.add(taskIdentity);
  }

  void selectAll() => selectedIds.addAll(tasks.map((task) => task.identity));

  void deselectAll() => selectedIds.clear();

  List<DownloadTask> get selectedTasks => tasks
      .where((task) => selectedIds.contains(task.identity))
      .toList(growable: false);

  Future<void> pauseTask(DownloadTask task) async {
    if (!task.canPause) return;
    if (await _sendTaskAction(task, 'pause')) {
      _updateTaskStatus(task.identity, DownloadStatus.paused);
    }
  }

  Future<void> resumeTask(DownloadTask task) async {
    if (!task.canResume) return;
    if (await _sendTaskAction(task, 'resume')) {
      _updateTaskStatus(task.identity, DownloadStatus.waiting);
    }
  }

  Future<void> retryTask(DownloadTask task) async {
    if (!task.canRetry) return;
    if (await _sendTaskAction(task, 'retry')) {
      _updateTaskStatus(task.identity, DownloadStatus.waiting);
    }
  }

  Future<void> deleteTask(DownloadTask task) async {
    if (!await _sendTaskAction(task, 'delete')) return;
    tasks.removeWhere((item) => item.identity == task.identity);
    selectedIds.remove(task.identity);
    _refreshStats();
    _persistTasks();
  }

  Future<void> openTask(DownloadTask task) async {
    if (!task.canOpen || task.contentUri == null) return;
    await _channel.invokeMethod<bool>('openContentUri', {
      'uri': task.contentUri,
      'mimeType': task.isAudio ? 'audio/*' : 'video/*',
    });
  }

  Future<void> shareTask(DownloadTask task) async {
    if (!task.canOpen || task.contentUri == null) return;
    await _channel.invokeMethod<bool>('shareContentUri', {
      'uri': task.contentUri,
      'mimeType': task.isAudio ? 'audio/*' : 'video/*',
      'displayName': task.displayName,
    });
  }

  Future<void> pauseSelected() async {
    for (final task in selectedTasks) {
      await pauseTask(task);
    }
  }

  Future<void> resumeSelected() async {
    for (final task in selectedTasks) {
      await resumeTask(task);
    }
  }

  Future<void> deleteSelected() async {
    for (final task in selectedTasks.toList(growable: false)) {
      await deleteTask(task);
    }
    exitSelectionMode();
  }

  Future<void> retryFailedSelected() async {
    for (final task in selectedTasks.where(
      (task) => task.status == DownloadStatus.failed,
    )) {
      await retryTask(task);
    }
  }

  Future<bool> _sendTaskAction(DownloadTask task, String action) async {
    try {
      await _channel.invokeMethod<Map<dynamic, dynamic>>('taskAction', {
        'requestId': task.requestId,
        'taskId': task.taskId,
        'action': action,
      });
      return true;
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Seal task action $action failed: ${error.code} ${error.message}',
        );
      }
    } on MissingPluginException catch (error) {
      if (kDebugMode) debugPrint('Seal task action unavailable: $error');
    }
    return false;
  }

  void _updateTaskStatus(String identity, DownloadStatus newStatus) {
    final index = tasks.indexWhere((task) => task.identity == identity);
    if (index < 0) return;
    tasks[index] = tasks[index].copyWith(
      status: newStatus,
      errorMessage: null,
      completedAt: null,
    );
    _refreshStats();
    _persistTasks();
  }

  Future<void> openSealReleases() => PageUtils.launchURL(releasesUrl);
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

void _recordDownloadManagerError(
  Object error,
  StackTrace stackTrace, {
  required String operation,
}) {
  CrashReporter.recordErrorSync(
    error,
    stackTrace,
    severity: CrashSeverity.handled,
    module: 'download_manager',
    operation: operation,
    reason: 'optional_download_manager_operation_failed',
  );
}
