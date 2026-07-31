import 'package:pili_plus/common/widgets/appbar/appbar.dart';
import 'package:pili_plus/services/watch_stats_controller.dart';
import 'package:pili_plus/utils/extension/num_ext.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class WatchStatsDashboardPage extends StatelessWidget {
  const WatchStatsDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WatchStatsController>(
      init: WatchStatsController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('我的观看统计'),
            actions: [
              PopupMenuButton(
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: () async {
                      SmartDialog.showLoading(msg: '导出中');
                      final path = await controller.exportAsJson();
                      SmartDialog.dismiss();
                      SmartDialog.showToast('已导出到: $path');
                    },
                    child: const Text('导出 JSON'),
                  ),
                  PopupMenuItem(
                    onTap: () async {
                      SmartDialog.showLoading(msg: '导出中');
                      final path = await controller.exportAsCsv();
                      SmartDialog.dismiss();
                      SmartDialog.showToast('已导出到: $path');
                    },
                    child: const Text('导出 CSV'),
                  ),
                  PopupMenuItem(
                    onTap: () => _showClearConfirm(context, controller),
                    child: const Text('清空统计'),
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

            final stats = controller.statsData.value;
            if (stats == null) {
              return const Center(child: Text('暂无数据'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodTabs(controller),
                  const SizedBox(height: 16),
                  _buildSummaryCards(stats),
                  const SizedBox(height: 24),
                  _buildDailyChart(stats),
                  const SizedBox(height: 24),
                  _buildTopCreators(stats),
                  const SizedBox(height: 24),
                  _buildLongestVideos(stats),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildPeriodTabs(WatchStatsController controller) {
    return Obx(() => SegmentedButton<WatchStatsPeriod>(
      segments: const [
        ButtonSegment(
          value: WatchStatsPeriod.week,
          label: Text('本周'),
        ),
        ButtonSegment(
          value: WatchStatsPeriod.month,
          label: Text('本月'),
        ),
        ButtonSegment(
          value: WatchStatsPeriod.all,
          label: Text('全部'),
        ),
      ],
      selected: {controller.selectedPeriod.value},
      onSelectionChanged: (selected) {
        controller.setPeriod(selected.first);
      },
    ));
  }

  Widget _buildSummaryCards(WatchStatsData stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.timer_outlined,
            title: '总观看时长',
            value: stats.formattedWatchTime,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.play_circle_outline,
            title: '观看视频数',
            value: stats.uniqueVideoCount.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.calendar_today_outlined,
            title: '日均时长',
            value: stats.formattedDailyAverage,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyChart(WatchStatsData stats) {
    if (stats.dailyWatchTime.isEmpty) {
      return Card(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: const Text('暂无每日数据'),
        ),
      );
    }

    // Get last 7 days for weekly, last 30 for monthly
    final days = stats.periodDays <= 7 ? 7 : 30;
    final now = DateTime.now();
    final dates = List.generate(days, (i) {
      final date = now.subtract(Duration(days: days - 1 - i));
      return DateFormat('MM-dd').format(date);
    });

    final maxValue = stats.dailyWatchTime.values.fold<int>(
      0,
      (max, val) => val > max ? val : max,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每日观看时长',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue > 0 ? maxValue.toDouble() * 1.2 : 3600,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final minutes = rod.toY ~/ 60;
                        final seconds = rod.toY % 60;
                        return BarTooltipItem(
                          '$minutes 分钟',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < dates.length &&
                              value.toInt() % (days > 7 ? 5 : 1) == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                dates[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final hours = value ~/ 3600;
                          final minutes = (value % 3600) ~/ 60;
                          if (hours > 0) {
                            return Text(
                              '${hours}h',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return Text(
                            '${minutes}m',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 3600,
                  ),
                  barGroups: List.generate(days, (index) {
                    final dateKey = DateFormat('yyyy-MM-dd').format(
                      now.subtract(Duration(days: days - 1 - index)),
                    );
                    final seconds = stats.dailyWatchTime[dateKey] ?? 0;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: seconds.toDouble(),
                          color: Colors.blue,
                          width: days > 7 ? 6 : 12,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCreators(WatchStatsData stats) {
    if (stats.topCreators.isEmpty) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '观看时长最多的 UP 主',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...stats.topCreators.asMap().entries.map((entry) {
              final index = entry.key;
              final creator = entry.value;
              final hours = creator.value ~/ 3600;
              final minutes = (creator.value % 3600) ~/ 60;
              final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _getRankColor(index),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        creator.key,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLongestVideos(WatchStatsData stats) {
    if (stats.longestVideos.isEmpty) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '观看时长最长的视频',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...stats.longestVideos.asMap().entries.map((entry) {
              final index = entry.key;
              final video = entry.value;
              final hours = video.value ~/ 3600;
              final minutes = (video.value % 3600) ~/ 60;
              final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _getRankColor(index),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        video.key,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey[400]!;
      case 2:
        return Colors.brown[400]!;
      default:
        return Colors.blue;
    }
  }

  void _showClearConfirm(BuildContext context, WatchStatsController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空统计'),
        content: const Text('确定要清空所有观看统计数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.clearStats();
              SmartDialog.showToast('已清空');
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
