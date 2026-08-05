import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pili_plus/controllers/video_bookmark_controller.dart';
import 'package:pili_plus/http/search.dart';
import 'package:pili_plus/models/video_bookmark.dart';
import 'package:pili_plus/pages/video/bookmark/video_bookmark_editor_dialog.dart';
import 'package:pili_plus/pages/video/bookmark/video_bookmark_list_controls.dart';
import 'package:pili_plus/pages/video/bookmark/video_bookmark_tile.dart';
import 'package:pili_plus/services/video_bookmark_service.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:pili_plus/utils/utils.dart';

class VideoBookmarkListPage extends StatefulWidget {
  const VideoBookmarkListPage({super.key, this.currentBvid});

  final String? currentBvid;

  @override
  State<VideoBookmarkListPage> createState() => _VideoBookmarkListPageState();
}

class _VideoBookmarkListPageState extends State<VideoBookmarkListPage> {
  late final VideoBookmarkController controller;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = VideoBookmarkController()..loadAllBookmarks();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _exportBookmarks() {
    Utils.copyText(
      controller.exportAllBookmarks(),
      toastText: '已复制到剪贴板',
    );
  }

  Future<void> _clearAllBookmarks() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空所有标记'),
        content: const Text('确定要清空所有视频标记吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) {
      return;
    }

    await controller.clearAllBookmarks();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清空所有标记')),
    );
  }

  Future<void> _openBookmark(VideoBookmark bookmark) async {
    try {
      final target = await SearchHttp.ab2cWithDimension(bvid: bookmark.bvid);
      if (!mounted) {
        return;
      }
      final cid = target?.cid;
      if (cid == null) {
        SmartDialog.showToast('无法获取视频播放信息');
        return;
      }

      await PageUtils.toVideoPage(
        bvid: bookmark.bvid,
        cid: cid,
        title: bookmark.videoTitle,
        progress: bookmark.timestampSeconds * 1000,
        dimension: target!.dimension,
      );
    } catch (error) {
      if (mounted) {
        SmartDialog.showToast('打开视频失败：$error');
      }
    }
  }

  Future<void> _showEditDialog(VideoBookmark bookmark) async {
    final result = await showVideoBookmarkEditorDialog(
      context: context,
      title: '编辑标记',
      timestampSeconds: bookmark.timestampSeconds,
      defaultName:
          '标记 @ ${VideoBookmark.formatTimestamp(bookmark.timestampSeconds)}',
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

  Future<void> _confirmDelete(VideoBookmark bookmark) async {
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

  String get _activeFilterLabel {
    return switch (controller.filterType.value) {
      BookmarkFilterType.all => '',
      BookmarkFilterType.currentVideo => '当前视频',
      BookmarkFilterType.creator =>
        '创作者 UID ${controller.authorMidFilter.value}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的视频标记'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: '筛选',
              onPressed: () => showVideoBookmarkFilterSheet(
                context: context,
                controller: controller,
                currentBvid: widget.currentBvid,
              ),
              icon: Icon(
                controller.filterType.value == BookmarkFilterType.all
                    ? Icons.filter_list
                    : Icons.filter_alt,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onPressed: () => showVideoBookmarkSortSheet(
              context: context,
              controller: controller,
            ),
          ),
          PopupMenuButton<_PageAction>(
            onSelected: (action) {
              switch (action) {
                case _PageAction.export:
                  _exportBookmarks();
                case _PageAction.clear:
                  _clearAllBookmarks();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _PageAction.export,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.upload_outlined),
                  title: Text('导出全部'),
                ),
              ),
              PopupMenuItem(
                value: _PageAction.clear,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    '清空全部',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: searchController,
              builder: (context, value, child) => TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: '搜索标记名称或备注…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            controller.search('');
                          },
                        ),
                ),
                onChanged: controller.search,
              ),
            ),
          ),
          Obx(() {
            if (controller.filterType.value == BookmarkFilterType.all) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: InputChip(
                  label: Text(_activeFilterLabel),
                  onDeleted: controller.clearFilter,
                ),
              ),
            );
          }),
          Expanded(
            child: Obx(() {
              final bookmarks = controller.allBookmarks;
              if (bookmarks.isEmpty) {
                final hasCriteria =
                    controller.searchQuery.value.trim().isNotEmpty ||
                    controller.filterType.value != BookmarkFilterType.all;
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 64,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        hasCriteria ? '没有找到相关标记' : '暂无视频标记',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasCriteria ? '尝试调整搜索或筛选条件' : '在视频播放时点击标记图标添加',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (controller.sortType.value == SortType.videoName) {
                return _buildGroupedList(bookmarks, theme);
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: bookmarks.length,
                itemBuilder: (context, index) =>
                    _buildBookmarkTile(bookmarks[index]),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(
    List<VideoBookmark> bookmarks,
    ThemeData theme,
  ) {
    final grouped = <String, List<VideoBookmark>>{};
    for (final bookmark in bookmarks) {
      grouped.putIfAbsent(bookmark.bvid, () => []).add(bookmark);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final videoBookmarks = grouped.values.elementAt(index);
        final videoTitle = videoBookmarks.first.videoTitle;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                videoTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...videoBookmarks.map(_buildBookmarkTile),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildBookmarkTile(VideoBookmark bookmark) {
    return VideoBookmarkTile(
      bookmark: bookmark,
      onTap: () => _openBookmark(bookmark),
      onEdit: () => _showEditDialog(bookmark),
      onDelete: () => _confirmDelete(bookmark),
    );
  }
}

enum _PageAction {
  export,
  clear,
}
