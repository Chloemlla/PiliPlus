import 'package:get/get.dart';
import 'package:pili_plus/models/download/download_task.dart';
import 'package:pili_plus/services/download_manager_service.dart';

/// Controller for the Download Manager UI.
class DownloadManagerController extends GetxController {
  late final DownloadManagerService _service;

  /// All tasks.
  List<DownloadTask> get tasks => _service.tasks;

  /// Stats.
  DownloadStats get stats => _service.stats.value;

  /// Selection mode.
  bool get isSelectionMode => _service.isSelectionMode.value;

  /// Selected task ids.
  Set<String> get selectedIds => _service.selectedIds;

  /// Whether Seal is installed.
  bool get isSealInstalled => _service.isSealInstalled.value;

  /// Number of selected tasks.
  int get selectedCount => selectedIds.length;

  /// Get selected tasks.
  List<DownloadTask> get selectedTasks => _service.selectedTasks;

  @override
  void onInit() {
    super.onInit();
    _service = Get.find<DownloadManagerService>();
  }

  Future<void> refreshStatus() => _service.refreshStatus();

  void enterSelectionMode() => _service.enterSelectionMode();

  void exitSelectionMode() => _service.exitSelectionMode();

  void toggleSelection(String requestId) => _service.toggleSelection(requestId);

  void selectAll() => _service.selectAll();

  void deselectAll() => _service.deselectAll();

  Future<void> pauseTask(DownloadTask task) => _service.pauseTask(task);

  Future<void> resumeTask(DownloadTask task) => _service.resumeTask(task);

  Future<void> retryTask(DownloadTask task) => _service.retryTask(task);

  Future<void> deleteTask(DownloadTask task) => _service.deleteTask(task);

  Future<void> openTask(DownloadTask task) => _service.openTask(task);

  Future<void> shareTask(DownloadTask task) => _service.shareTask(task);

  Future<void> pauseSelected() => _service.pauseSelected();

  Future<void> resumeSelected() => _service.resumeSelected();

  Future<void> deleteSelected() => _service.deleteSelected();

  Future<void> retryFailedSelected() => _service.retryFailedSelected();

  Future<void> openSealReleases() => _service.openSealReleases();
}
