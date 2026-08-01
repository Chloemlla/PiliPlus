import 'package:flutter/material.dart';
import 'package:pili_plus/services/watch_stats_service.dart';

class WatchStatsRankings extends StatelessWidget {
  const WatchStatsRankings({required this.stats, super.key});

  final WatchStatsData stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final creators = _RankingCard(
          title: '观看时长最多的 UP 主',
          emptyLabel: '暂无 UP 主统计',
          rows: stats.topCreators
              .map(
                (creator) => _RankingRowData(
                  title: creator.authorName,
                  subtitle: creator.authorMid > 0
                      ? 'UID ${creator.authorMid}'
                      : null,
                  watchedSeconds: creator.watchedSeconds,
                ),
              )
              .toList(),
        );
        final videos = _RankingCard(
          title: '观看时长最长的视频',
          emptyLabel: '暂无视频统计',
          rows: stats.longestVideos
              .map(
                (video) => _RankingRowData(
                  title: video.title,
                  subtitle: '${video.authorName} · ${video.bvid}',
                  watchedSeconds: video.watchedSeconds,
                ),
              )
              .toList(),
        );
        if (!wide) {
          return Column(
            children: [creators, const SizedBox(height: 16), videos],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: creators),
            const SizedBox(width: 16),
            Expanded(child: videos),
          ],
        );
      },
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.emptyLabel,
    required this.rows,
  });

  final String title;
  final String emptyLabel;
  final List<_RankingRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text(emptyLabel)),
              )
            else
              for (final (index, row) in rows.indexed)
                _RankingRow(index: index, data: row),
          ],
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.index, required this.data});

  final int index;
  final _RankingRowData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rankColor = switch (index) {
      0 => colorScheme.tertiary,
      1 => colorScheme.secondary,
      2 => colorScheme.primary,
      _ => colorScheme.outline,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: rankColor,
            foregroundColor: colorScheme.surface,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (data.subtitle case final subtitle?)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            WatchStatsData.formatWatchDuration(data.watchedSeconds),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

final class _RankingRowData {
  const _RankingRowData({
    required this.title,
    required this.subtitle,
    required this.watchedSeconds,
  });

  final String title;
  final String? subtitle;
  final int watchedSeconds;
}
