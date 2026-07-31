import 'package:get/get.dart';
import 'package:pili_plus/services/watch_stats_service.dart';

enum WatchStatsPeriod { week, month, all }

class WatchStatsController extends GetxController {
  WatchStatsService get _service => WatchStatsService.instance;

  final Rx<WatchStatsPeriod> selectedPeriod = WatchStatsPeriod.week.obs;

  final RxBool isLoading = true.obs;
  final Rx<WatchStatsData?> statsData = Rx<WatchStatsData?>(null);

  @override
  void onInit() {
    super.onInit();
    _initService();
  }

  Future<void> _initService() async {
    await _service.init();
    await loadStats();
  }

  Future<void> loadStats() async {
    isLoading.value = true;
    try {
      final sessions = _getSessionsForPeriod(selectedPeriod.value);
      statsData.value = _computeStats(sessions, selectedPeriod.value);
    } finally {
      isLoading.value = false;
    }
  }

  List<dynamic> _getSessionsForPeriod(WatchStatsPeriod period) {
    switch (period) {
      case WatchStatsPeriod.week:
        return _service.getSessionsForDays(7);
      case WatchStatsPeriod.month:
        return _service.getSessionsForDays(30);
      case WatchStatsPeriod.all:
        return _service.getSessionsForDays(365 * 10); // Effectively all data
    }
  }

  WatchStatsData _computeStats(List<dynamic> sessions, WatchStatsPeriod period) {
    final periodDays = switch (period) {
      WatchStatsPeriod.week => 7,
      WatchStatsPeriod.month => 30,
      WatchStatsPeriod.all => 365,
    };

    final totalWatchTime = _service.getTotalWatchTime(
      sessions.cast(),
    );
    final uniqueVideos = _service.getUniqueVideoCount(sessions.cast());
    final dailyWatchTime = _service.getDailyWatchTime(sessions.cast());
    final topCreators = _service.getTopCreators(sessions.cast());
    final longestVideos = _service.getLongestVideos(sessions.cast());

    // Count unique creators
    final uniqueCreators = sessions
        .map((s) => (s as dynamic).authorMid)
        .toSet()
        .length;

    return WatchStatsData(
      totalWatchTimeSeconds: totalWatchTime,
      videosWatched: sessions.length,
      uniqueVideoCount: uniqueVideos,
      uniqueCreatorCount: uniqueCreators,
      dailyWatchTime: dailyWatchTime,
      topCreators: topCreators,
      longestVideos: longestVideos,
      periodDays: periodDays,
    );
  }

  void setPeriod(WatchStatsPeriod period) {
    if (selectedPeriod.value != period) {
      selectedPeriod.value = period;
      loadStats();
    }
  }

  Future<void> clearStats() async {
    await _service.clearAll();
    await loadStats();
  }

  Future<String> exportAsJson() async {
    final content = await _service.exportAsJson();
    final file = await _service.saveExport('watch_stats.json', content);
    return file.path;
  }

  Future<String> exportAsCsv() async {
    final content = await _service.exportAsCsv();
    final file = await _service.saveExport('watch_stats.csv', content);
    return file.path;
  }
}
