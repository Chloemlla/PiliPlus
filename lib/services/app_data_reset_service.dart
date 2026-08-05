import 'package:pili_plus/services/download_task_repository.dart';
import 'package:pili_plus/services/live_alert_service.dart';
import 'package:pili_plus/services/video_bookmark_service.dart';
import 'package:pili_plus/services/watch_stats_service.dart';
import 'package:pili_plus/utils/storage.dart';

/// Clears feature-owned stores before the shared account/settings storage.
abstract final class AppDataResetService {
  static Future<void> clearAll() async {
    await Future.wait([
      LiveAlertService.instance.clearAllData(),
      DownloadTaskRepository().clear(),
      VideoBookmarkService.clearAllBookmarks(),
      WatchStatsService.instance.clearAll(),
    ]);
    await GStorage.clear();
  }
}
