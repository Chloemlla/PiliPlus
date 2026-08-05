import 'dart:async' show unawaited;

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pili_plus/services/watch_stats_service.dart';

class WatchStatsController extends GetxController {
  WatchStatsController({WatchStatsService? service})
    : _service = service ?? WatchStatsService.instance;

  final WatchStatsService _service;

  final Rx<WatchStatsPeriod> selectedPeriod = WatchStatsPeriod.week.obs;
  final RxBool isLoading = true.obs;
  final Rxn<WatchStatsData> statsData = Rxn<WatchStatsData>();
  final Rxn<WatchStatsData> weeklyStats = Rxn<WatchStatsData>();
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _service.init();
      await loadStats();
    } catch (error) {
      errorMessage.value = error.toString();
      isLoading.value = false;
    }
  }

  Future<void> loadStats() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      statsData.value = _service.getStats(selectedPeriod.value);
      weeklyStats.value = selectedPeriod.value == WatchStatsPeriod.week
          ? statsData.value
          : _service.getStats(WatchStatsPeriod.week);
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void setPeriod(WatchStatsPeriod period) {
    if (selectedPeriod.value == period) return;
    selectedPeriod.value = period;
    unawaited(loadStats());
  }

  Future<void> clearStats() async {
    await _service.clearAll();
    await loadStats();
  }

  Future<String> exportAsJson() async {
    final content = await _service.exportAsJson();
    final file = await _service.saveExport(_exportFilename('json'), content);
    return file.path;
  }

  Future<String> exportAsCsv() async {
    final content = await _service.exportAsCsv();
    final file = await _service.saveExport(_exportFilename('csv'), content);
    return file.path;
  }

  String get weeklyComparisonLabel {
    final stats = weeklyStats.value;
    if (stats == null || stats.previousPeriodWatchTimeSeconds <= 0) {
      return '上周暂无可比较数据';
    }
    final comparison = stats.comparisonToPrevious ?? 0;
    if (comparison.abs() < 0.005) return '与上周基本持平';
    final percent = (comparison.abs() * 100).round();
    return comparison > 0 ? '较上周增加 $percent%' : '较上周减少 $percent%';
  }

  String get weeklyShareText {
    final stats = weeklyStats.value;
    if (stats == null) return '我的本周观看统计';
    return '本周观看 ${stats.formattedWatchTime}，'
        '${stats.videosWatched} 个视频，$weeklyComparisonLabel。';
  }

  static String _exportFilename(String extension) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'pili_watch_stats_$timestamp.$extension';
  }
}
