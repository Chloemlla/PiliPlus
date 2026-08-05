import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/controllers/video_bookmark_controller.dart';
import 'package:pili_plus/models/video_bookmark.dart';
import 'package:pili_plus/pages/video/bookmark/video_bookmark_editor_dialog.dart';
import 'package:pili_plus/pages/video/bookmark/video_bookmark_list_page.dart';
import 'package:pili_plus/pages/video/bookmark/video_bookmark_tile.dart';

class VideoBookmarkSheet extends StatefulWidget {
  const VideoBookmarkSheet({
    super.key,
    required this.bvid,
    required this.videoTitle,
    this.authorMid,
    required this.currentTimestamp,
    required this.onBookmarkTap,
  });

  final String bvid;
  final String videoTitle;
  final int? authorMid;
  final int currentTimestamp;
  final ValueChanged<VideoBookmark> onBookmarkTap;

  @override
  State<VideoBookmarkSheet> createState() => _VideoBookmarkSheetState();
}

class _VideoBookmarkSheetState extends State<VideoBookmarkSheet> {
  late final VideoBookmarkController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoBookmarkController()..loadBookmarksForVideo(widget.bvid);
  }

  String _defaultName(int timestampSeconds) =>
      '标记 @ ${VideoBookmark.formatTimestamp(timestampSeconds)}';

  Future<void> _showAddBookmarkDialog() async {
    final result = await showVideoBookmarkEditorDialog(
      context: context,
      title: '添加标记',
      timestampSeconds: widget.currentTimestamp,
      defaultName: _defaultName(widget.currentTimestamp),
    );
    if (!mounted || result == null) {
      return;
    }

    final bookmark = await controller.addBookmark(
      bvid: widget.bvid,
      videoTitle: widget.videoTitle,
      authorMid: widget.authorMid,
      timestampSeconds: widget.currentTimestamp,
      name: result.name,
      note: result.note,
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          bookmark == null ? '该视频标记数量已达上限（200个）' : '已添加标记',
        ),
      ),
    );
  }

  Future<void> _showEditBookmarkDialog(VideoBookmark bookmark) async {
    final result = await showVideoBookmarkEditorDialog(
      context: context,
      title: '编辑标记',
      timestampSeconds: bookmark.timestampSeconds,
      defaultName: _defaultName(bookmark.timestampSeconds),
      initialName: bookmark.name,
      initialNote: bookmark.note,
    );
    if (!mounted || result == null) {
      return;
    }

    await controller.updateBookmark(
      bookmark.copyWithDetails(name: result.name, note: result.note),
    );
  }

  Future<void> _confirmDeleteBookmark(VideoBookmark bookmark) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除标记'),
        content: Text('确定要删除“${bookmark.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) {
      return;
    }
    await controller.deleteBookmark(bookmark);
  }

  void _openAllBookmarks() {
    Navigator.pop(context);
    Get.to(() => VideoBookmarkListPage(currentBvid: widget.bvid));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.6;

    return Material(
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  Text('视频标记', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    tooltip: '查看全部标记',
                    onPressed: _openAllBookmarks,
                    icon: const Icon(Icons.list_alt),
                  ),
                  TextButton.icon(
                    onPressed: _showAddBookmarkDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加'),
                  ),
                ],
              ),
            ),
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
                          '点击“添加”保存当前播放位置',
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
                    return VideoBookmarkTile(
                      bookmark: bookmark,
                      showVideoTitle: false,
                      useCard: false,
                      onTap: () {
                        widget.onBookmarkTap(bookmark);
                        Navigator.pop(context);
                      },
                      onEdit: () => _showEditBookmarkDialog(bookmark),
                      onDelete: () => _confirmDeleteBookmark(bookmark),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
