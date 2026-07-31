import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/video_bookmark.dart';
import 'package:pili_plus/controllers/video_bookmark_controller.dart';

class VideoBookmarkSheet extends StatefulWidget {
  final String bvid;
  final String videoTitle;
  final int? authorMid;
  final int currentTimestamp;
  final Function(VideoBookmark) onBookmarkTap;

  const VideoBookmarkSheet({
    super.key,
    required this.bvid,
    required this.videoTitle,
    this.authorMid,
    required this.currentTimestamp,
    required this.onBookmarkTap,
  });

  @override
  State<VideoBookmarkSheet> createState() => _VideoBookmarkSheetState();
}

class _VideoBookmarkSheetState extends State<VideoBookmarkSheet> {
  late final VideoBookmarkController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(VideoBookmarkController());
    controller.loadBookmarksForVideo(widget.bvid);
  }

  @override
  void dispose() {
    Get.delete<VideoBookmarkController>();
    super.dispose();
  }

  String _formatTimestamp(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showAddBookmarkDialog() {
    final nameController = TextEditingController();
    final noteController = TextEditingController();
    final timestamp = widget.currentTimestamp;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '时间: ${_formatTimestamp(timestamp)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: '标记名称',
                hintText: '标记 @ ${_formatTimestamp(timestamp)}',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final note = noteController.text.trim();

              final bookmark = await controller.addBookmark(
                bvid: widget.bvid,
                videoTitle: widget.videoTitle,
                authorMid: widget.authorMid,
                timestampSeconds: timestamp,
                name: name.isEmpty ? null : name,
                note: note.isEmpty ? null : note,
              );

              if (mounted) {
                Navigator.pop(context);
                if (bookmark != null) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('已添加标记')),
                  );
                } else {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('该视频标记数量已达上限（200个）')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showEditBookmarkDialog(VideoBookmark bookmark) {
    final nameController = TextEditingController(text: bookmark.name);
    final noteController = TextEditingController(text: bookmark.note ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑标记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '标记名称',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              bookmark.name = nameController.text.trim();
              bookmark.note = noteController.text.trim().isEmpty
                  ? null
                  : noteController.text.trim();
              await controller.updateBookmark(bookmark);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_outline),
                const SizedBox(width: 8),
                Text(
                  '视频标记',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showAddBookmarkDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
          ),

          // Bookmark list
          Expanded(
            child: Obx(() {
              final bookmarks = controller.bookmarks;

              if (bookmarks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '暂无标记',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击"添加"按钮添加标记',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  final bookmark = bookmarks[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        bookmark.formattedTimestamp,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(bookmark.name),
                    subtitle: bookmark.note != null && bookmark.note!.isNotEmpty
                        ? Text(
                            bookmark.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'edit':
                            _showEditBookmarkDialog(bookmark);
                            break;
                          case 'delete':
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('删除标记'),
                                content: Text('确定要删除"${bookmark.name}"吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await controller.deleteBookmark(bookmark);
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('编辑'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('删除'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      widget.onBookmarkTap(bookmark);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
