import 'package:flutter/material.dart';
import 'package:pili_plus/models/download/download_task.dart';
import 'package:pili_plus/pages/download_manager/controller.dart';

/// Individual card for a download task.
class DownloadTaskCard extends StatelessWidget {
  const DownloadTaskCard({
    super.key,
    required this.task,
    required this.controller,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  final DownloadTask task;
  final DownloadManagerController controller;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelectionMode = controller.isSelectionMode;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (isSelectionMode) {
            controller.toggleSelection(task.requestId);
          } else {
            onTap?.call();
          }
        },
        onLongPress: () {
          if (!isSelectionMode) {
            controller
              ..enterSelectionMode()
              ..toggleSelection(task.requestId);
          }
          onLongPress?.call();
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: isSelected
                ? Border(
                    left: BorderSide(color: cs.primary, width: 3),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) =>
                        controller.toggleSelection(task.requestId),
                  ),
                  const SizedBox(width: 4),
                ],
                _StatusIndicator(status: task.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            task.isAudio
                                ? Icons.music_note_rounded
                                : Icons.movie_outlined,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatusChip(status: task.status),
                          if (task.quality.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              task.quality,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (task.status == DownloadStatus.downloading ||
                              task.status == DownloadStatus.waiting) ...[
                            Text(
                              task.formattedSize,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ] else if (task.status == DownloadStatus.completed) ...[
                            Text(
                              '已存储',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (task.status == DownloadStatus.downloading) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: task.progress,
                            minHeight: 3,
                            backgroundColor: cs.surfaceContainerHighest,
                          ),
                        ),
                      ],
                      if (task.errorMessage != null &&
                          task.status == DownloadStatus.failed) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.errorMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isSelectionMode) ...[
                  const SizedBox(width: 8),
                  _ActionButton(task: task, controller: controller),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(cs);
    final icon = _statusIcon;

    if (status == DownloadStatus.downloading || status == DownloadStatus.waiting) {
      return SizedBox(
        width: 32,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              color: color.withValues(alpha: 0.6),
            ),
            Icon(icon, size: 16, color: color),
          ],
        ),
      );
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  Color _statusColor(ColorScheme cs) {
    return switch (status) {
      DownloadStatus.waiting => cs.tertiary,
      DownloadStatus.downloading => cs.primary,
      DownloadStatus.paused => cs.outline,
      DownloadStatus.completed => cs.primary,
      DownloadStatus.failed => cs.error,
    };
  }

  IconData get _statusIcon {
    return switch (status) {
      DownloadStatus.waiting => Icons.hourglass_empty_rounded,
      DownloadStatus.downloading => Icons.cloud_download_rounded,
      DownloadStatus.paused => Icons.pause_rounded,
      DownloadStatus.completed => Icons.check_rounded,
      DownloadStatus.failed => Icons.error_outline_rounded,
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final DownloadStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _statusColor(cs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _statusLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme cs) {
    return switch (status) {
      DownloadStatus.waiting => cs.tertiary,
      DownloadStatus.downloading => cs.primary,
      DownloadStatus.paused => cs.outline,
      DownloadStatus.completed => cs.primary,
      DownloadStatus.failed => cs.error,
    };
  }

  String get _statusLabel {
    return switch (status) {
      DownloadStatus.waiting => '等待',
      DownloadStatus.downloading => '下载',
      DownloadStatus.paused => '暂停',
      DownloadStatus.completed => '完成',
      DownloadStatus.failed => '失败',
    };
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.task,
    required this.controller,
  });

  final DownloadTask task;
  final DownloadManagerController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      itemBuilder: (context) => _buildMenuItems(),
      onSelected: (action) => _handleAction(action, context),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    final items = <PopupMenuEntry<String>>[];

    if (task.canPause) {
      items.add(const PopupMenuItem(
        value: 'pause',
        child: Row(
          children: [
            Icon(Icons.pause_rounded, size: 20),
            SizedBox(width: 8),
            Text('暂停'),
          ],
        ),
      ));
    }

    if (task.canResume) {
      items.add(const PopupMenuItem(
        value: 'resume',
        child: Row(
          children: [
            Icon(Icons.play_arrow_rounded, size: 20),
            SizedBox(width: 8),
            Text('继续'),
          ],
        ),
      ));
    }

    if (task.canRetry) {
      items.add(const PopupMenuItem(
        value: 'retry',
        child: Row(
          children: [
            Icon(Icons.refresh_rounded, size: 20),
            SizedBox(width: 8),
            Text('重试'),
          ],
        ),
      ));
    }

    if (task.canOpen) {
      items
        ..add(const PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 20),
              SizedBox(width: 8),
              Text('打开文件'),
            ],
          ),
        ))
        ..add(const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share_rounded, size: 20),
              SizedBox(width: 8),
              Text('分享'),
            ],
          ),
        ));
    }

    items
      ..add(const PopupMenuDivider())
      ..add(const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
            SizedBox(width: 8),
            Text('删除', style: TextStyle(color: Colors.red)),
          ],
        ),
      ));

    return items;
  }

  Future<void> _handleAction(String action, BuildContext context) async {
    switch (action) {
      case 'pause':
        await controller.pauseTask(task);
      case 'resume':
        await controller.resumeTask(task);
      case 'retry':
        await controller.retryTask(task);
      case 'open':
        await controller.openTask(task);
      case 'share':
        await controller.shareTask(task);
      case 'delete':
        final confirmed = await _showDeleteConfirmation(context);
        if (confirmed) {
          await controller.deleteTask(task);
        }
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    if (task.status == DownloadStatus.downloading) {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('确认删除'),
              content: Text('确定要删除"${task.title}"吗？下载中的任务将被取消。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('删除'),
                ),
              ],
            ),
          ) ??
          false;
    }
    return true;
  }
}
