import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pili_plus/services/watch_stats_service.dart';

class WatchStatsBarChart extends StatelessWidget {
  const WatchStatsBarChart({required this.stats, super.key});

  final WatchStatsData stats;

  @override
  Widget build(BuildContext context) {
    final points = stats.dailyWatchTime;
    final maxSeconds = points.fold<int>(
      0,
      (value, point) => max(value, point.watchedSeconds),
    );
    if (maxSeconds == 0) {
      return const Card(
        child: SizedBox(
          height: 180,
          child: Center(child: Text('这个时间范围内还没有观看记录')),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final labelStep = points.length <= 7
        ? 1
        : points.length <= 30
        ? 5
        : 14;
    final maxY = maxSeconds * 1.15;
    final horizontalInterval = max(60, (maxY / 4).ceil()).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '每日观看时长',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final point = points[group.x];
                        return BarTooltipItem(
                          '${DateFormat('MM-dd').format(point.date)}\n'
                          '${WatchStatsData.formatWatchDuration(point.watchedSeconds)}',
                          TextStyle(color: colorScheme.onInverseSurface),
                        );
                      },
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: horizontalInterval,
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: horizontalInterval,
                        getTitlesWidget: (value, meta) => Text(
                          _axisDuration(value.round()),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 ||
                              index >= points.length ||
                              index % labelStep != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              DateFormat('MM-dd').format(points[index].date),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: points.indexed.map((entry) {
                    final (index, point) = entry;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: point.watchedSeconds.toDouble(),
                          width: points.length <= 7
                              ? 14
                              : points.length <= 30
                              ? 7
                              : 3,
                          color: colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _axisDuration(int seconds) {
    const secondsPerHour = Duration.secondsPerMinute * Duration.minutesPerHour;
    if (seconds >= secondsPerHour) {
      final hours = seconds / secondsPerHour;
      return '${hours.toStringAsFixed(hours >= 10 ? 0 : 1)}h';
    }
    return '${max(0, seconds ~/ Duration.secondsPerMinute)}m';
  }
}
