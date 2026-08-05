import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/pages/download_manager/controller.dart';
import 'package:pili_plus/pages/download_manager/widgets/download_task_card.dart';

/// Main page for managing Seal download tasks.
class DownloadManagerPage extends StatelessWidget {
  const DownloadManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DownloadManagerController>(
      init: DownloadManagerController(),
      builder: (controller) {
        return Scaffold(
          appBar: _buildAppBar(controller),
          body: Obx(() {
            if (!controller.isSealInstalled) {
              return _SealNotInstalledView(controller: controller);
            }
            if (controller.tasks.isEmpty) {
              return const _EmptyView();
            }
            return _TaskListView(controller: controller);
          }),
          bottomNavigationBar: Obx(() {
            if (!controller.isSelectionMode || controller.tasks.isEmpty) {
              return const SizedBox.shrink();
            }
            return _BatchActionsBar(controller: controller);
          }),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(DownloadManagerController controller) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Obx(() {
        final isSelectionMode = controller.isSelectionMode;
        final selectedCount = controller.selectedCount;

        if (isSelectionMode) {
          return AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: controller.exitSelectionMode,
            ),
            title: Text('已选择 $selectedCount 项'),
            actions: [
              IconButton(
                icon: const Icon(Icons.select_all),
                onPressed: controller.selectAll,
                tooltip: '全选',
              ),
              IconButton(
                icon: const Icon(Icons.deselect),
                onPressed: controller.deselectAll,
                tooltip: '取消全选',
              ),
            ],
          );
        }

        return AppBar(
          title: const Text('下载管理'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: controller.refreshStatus,
              tooltip: '刷新',
            ),
          ],
        );
      }),
    );
  }
}

class _TaskListView extends StatelessWidget {
  const _TaskListView({required this.controller});

  final DownloadManagerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatsBar(controller: controller),
        Expanded(
          child: Obx(() {
            final tasks = controller.tasks;
            return RefreshIndicator(
              onRefresh: controller.refreshStatus,
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 80),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return Obx(
                    () => DownloadTaskCard(
                      task: task,
                      controller: controller,
                      isSelected: controller.selectedIds.contains(
                        task.identity,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.controller});

  final DownloadManagerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Obx(() {
      final stats = controller.stats;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(
            bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            _StatChip(
              label: '总计',
              value: stats.total.toString(),
              color: cs.primary,
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: '完成',
              value: stats.completed.toString(),
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: '下载',
              value: stats.downloading.toString(),
              color: cs.primary,
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: '等待',
              value: stats.waiting.toString(),
              color: cs.tertiary,
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: '失败',
              value: stats.failed.toString(),
              color: cs.error,
            ),
            const Spacer(),
            if (stats.totalBytes > 0)
              Text(
                '已用 ${stats.formattedStorageUsed}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$value$label',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _BatchActionsBar extends StatelessWidget {
  const _BatchActionsBar({required this.controller});

  final DownloadManagerController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(() {
              final hasActive = controller.selectedTasks.any(
                (t) => t.status.isActive,
              );
              return OutlinedButton.icon(
                onPressed: hasActive ? controller.pauseSelected : null,
                icon: const Icon(Icons.pause_rounded, size: 18),
                label: const Text('暂停'),
              );
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() {
              final hasPaused = controller.selectedTasks.any(
                (t) => t.canResume,
              );
              return OutlinedButton.icon(
                onPressed: hasPaused ? controller.resumeSelected : null,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('继续'),
              );
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Obx(() {
              final hasFailed = controller.selectedTasks.any((t) => t.canRetry);
              return OutlinedButton.icon(
                onPressed: hasFailed ? controller.retryFailedSelected : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
              );
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认删除'),
                    content: Text(
                      '确定要删除选中的 ${controller.selectedCount} 个任务吗？',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  controller.deleteSelected();
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('删除'),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SealNotInstalledView extends StatelessWidget {
  const _SealNotInstalledView({required this.controller});

  final DownloadManagerController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_rounded,
              size: 72,
              color: cs.outline,
            ),
            const SizedBox(height: 24),
            Text(
              '未安装 Seal',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '下载管理功能需要 Seal 配合使用，'
              '请先安装 Seal 以管理下载任务。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: controller.openSealReleases,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('前往安装 Seal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 72,
              color: cs.outline,
            ),
            const SizedBox(height: 24),
            Text(
              '暂无下载任务',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '从视频详情页点击下载按钮，'
              '即可在此查看和管理下载任务。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
