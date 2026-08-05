import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pili_plus/pages/watch_stats/widgets/watch_stats_bar_chart.dart';
import 'package:pili_plus/pages/watch_stats/widgets/watch_stats_rankings.dart';
import 'package:pili_plus/pages/watch_stats/widgets/watch_stats_summary.dart';
import 'package:pili_plus/services/watch_stats_controller.dart';
import 'package:pili_plus/utils/share_utils.dart';
import 'package:share_plus/share_plus.dart';

class WatchStatsDashboardPage extends StatefulWidget {
  const WatchStatsDashboardPage({super.key});

  @override
  State<WatchStatsDashboardPage> createState() =>
      _WatchStatsDashboardPageState();
}

class _WatchStatsDashboardPageState extends State<WatchStatsDashboardPage> {
  final GlobalKey _shareBoundaryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WatchStatsController>(
      init: WatchStatsController(),
      builder: (controller) => Scaffold(
        appBar: AppBar(
          title: const Text('我的观看统计'),
          actions: [
            PopupMenuButton<_WatchStatsAction>(
              onSelected: (action) => _handleAction(controller, action),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _WatchStatsAction.shareWeekly,
                  child: Text('分享本周总结'),
                ),
                PopupMenuItem(
                  value: _WatchStatsAction.exportJson,
                  child: Text('导出 JSON'),
                ),
                PopupMenuItem(
                  value: _WatchStatsAction.exportCsv,
                  child: Text('导出 CSV'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: _WatchStatsAction.clear,
                  child: Text('清空统计'),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value case final error?) {
            return _ErrorState(
              message: error,
              onRetry: controller.loadStats,
            );
          }

          final stats = controller.statsData.value;
          final weeklyStats = controller.weeklyStats.value;
          if (stats == null || weeklyStats == null) {
            return const Center(child: Text('暂无统计数据'));
          }

          return RefreshIndicator(
            onRefresh: controller.loadStats,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                WatchStatsPeriodSelector(
                  selected: controller.selectedPeriod.value,
                  onSelected: controller.setPeriod,
                ),
                const SizedBox(height: 16),
                RepaintBoundary(
                  key: _shareBoundaryKey,
                  child: WatchStatsWeeklyShareCard(
                    stats: weeklyStats,
                    comparisonLabel: controller.weeklyComparisonLabel,
                  ),
                ),
                const SizedBox(height: 16),
                WatchStatsSummaryGrid(stats: stats),
                const SizedBox(height: 24),
                WatchStatsBarChart(stats: stats),
                const SizedBox(height: 24),
                WatchStatsRankings(stats: stats),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _handleAction(
    WatchStatsController controller,
    _WatchStatsAction action,
  ) async {
    switch (action) {
      case _WatchStatsAction.shareWeekly:
        await _shareWeeklySummary(controller);
      case _WatchStatsAction.exportJson:
        await _export(controller.exportAsJson);
      case _WatchStatsAction.exportCsv:
        await _export(controller.exportAsCsv);
      case _WatchStatsAction.clear:
        await _confirmClear(controller);
    }
  }

  Future<void> _export(Future<String> Function() exporter) async {
    SmartDialog.showLoading(msg: '正在导出');
    try {
      final path = await exporter();
      SmartDialog.showToast('已导出到 $path');
    } catch (error) {
      SmartDialog.showToast('导出失败：$error');
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> _shareWeeklySummary(WatchStatsController controller) async {
    SmartDialog.showLoading(msg: '正在生成总结卡片');
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _shareBoundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('总结卡片尚未准备完成');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('无法生成总结图片');
        final filename =
            'pili_watch_week_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';
        await SharePlus.instance.share(
          ShareParams(
            text: controller.weeklyShareText,
            files: [
              XFile.fromData(
                data.buffer.asUint8List(),
                name: filename,
                mimeType: 'image/png',
              ),
            ],
            sharePositionOrigin: await ShareUtils.sharePositionOrigin,
          ),
        );
      } finally {
        image.dispose();
      }
    } catch (error) {
      SmartDialog.showToast('分享失败：$error');
    } finally {
      SmartDialog.dismiss();
    }
  }

  Future<void> _confirmClear(WatchStatsController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空观看统计'),
        content: const Text('所有观看统计都只保存在本机。清空后无法恢复，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    SmartDialog.showLoading(msg: '正在清空');
    try {
      await controller.clearStats();
      SmartDialog.showToast('观看统计已清空');
    } catch (error) {
      SmartDialog.showToast('清空失败：$error');
    } finally {
      SmartDialog.dismiss();
    }
  }
}

enum _WatchStatsAction { shareWeekly, exportJson, exportCsv, clear }

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text('观看统计加载失败'),
            const SizedBox(height: 6),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
