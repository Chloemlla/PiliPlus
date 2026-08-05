import 'package:flutter/material.dart';
import 'package:pili_plus/services/watch_stats_service.dart';

class WatchStatsPeriodSelector extends StatelessWidget {
  const WatchStatsPeriodSelector({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final WatchStatsPeriod selected;
  final ValueChanged<WatchStatsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<WatchStatsPeriod>(
      segments: const [
        ButtonSegment(value: WatchStatsPeriod.week, label: Text('本周')),
        ButtonSegment(value: WatchStatsPeriod.month, label: Text('本月')),
        ButtonSegment(value: WatchStatsPeriod.all, label: Text('全部')),
      ],
      selected: {selected},
      onSelectionChanged: (selection) => onSelected(selection.first),
    );
  }
}

class WatchStatsSummaryGrid extends StatelessWidget {
  const WatchStatsSummaryGrid({required this.stats, super.key});

  final WatchStatsData stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _SummaryCard(
              width: width,
              icon: Icons.timer_outlined,
              label: '总观看时长',
              value: stats.formattedWatchTime,
            ),
            _SummaryCard(
              width: width,
              icon: Icons.play_circle_outline,
              label: '观看视频数',
              value: '${stats.videosWatched}',
            ),
            _SummaryCard(
              width: width,
              icon: Icons.calendar_today_outlined,
              label: '日均观看',
              value: stats.formattedDailyAverage,
            ),
          ],
        );
      },
    );
  }
}

class WatchStatsWeeklyShareCard extends StatelessWidget {
  const WatchStatsWeeklyShareCard({
    required this.stats,
    required this.comparisonLabel,
    super.key,
  });

  final WatchStatsData stats;
  final String comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.auto_graph_rounded,
              size: 42,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的本周观看总结',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${stats.formattedWatchTime} · ${stats.videosWatched} 个视频',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comparisonLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
