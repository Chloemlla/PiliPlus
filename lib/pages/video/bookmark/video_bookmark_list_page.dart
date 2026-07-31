import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/models/video_bookmark.dart';
import 'package:pili_plus/controllers/video_bookmark_controller.dart';
import 'package:pili_plus/services/video_bookmark_service.dart';
import 'package:pili_plus/utils/utils.dart';

class VideoBookmarkListPage extends StatefulWidget {
  const VideoBookmarkListPage({super.key});

  @override
  State<VideoBookmarkListPage> createState() => _VideoBookmarkListPageState();
}

class _VideoBookmarkListPageState extends State<VideoBookmarkListPage> {
  late final VideoBookmarkController controller;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(VideoBookmarkController());
    controller.loadAllBookmarks();
  }

  @override
  void dispose() {
    searchController.dispose();
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

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('最近添加'),
              trailing: controller.sortType.value == SortType.mostRecent
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                controller.setSortType(SortType.mostRecent);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('按视频名称'),
              trailing: controller.sortType.value == SortType.videoName
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                controller.setSortType(SortType.videoName);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('按时间戳'),
              trailing: controller.sortType.value == SortType.timestamp
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                controller.setSortType(SortType.timestamp);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBookmarks() async {
    final json = controller.exportAllBookmarks();
    Utils.copyText(json);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  Future<void> _clearAllBookmarks() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有标记'),
        content: const Text('确定要清空所有视频标记吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.clearAllBookmarks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清空所有标记')),
        );
      }
    }
  }

  void _showBookmarkOptions(VideoBookmark bookmark) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('跳转到标记'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to video at timestamp
                Get.toNamed('/video', arguments: {
                  'bvid': bookmark.bvid,
                  'cid': null, // Will be fetched from video detail
                  'heroTag': Utils.makeHeroTag(bookmark.bvid),
                  'seekTo': bookmark.timestampSeconds,
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(bookmark);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await controller.deleteBookmark(bookmark);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(VideoBookmark bookmark) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的视频标记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onPressed: _showSortOptions,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportBookmarks();
                  break;
                case 'clear':
                  _clearAllBookmarks();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload_outlined),
                    SizedBox(width: 8),
                    Text('导出全部'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('清空全部', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: '搜索标记名称或备注...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          controller.search('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                controller.search(value);
                setState(() {});
              },
            ),
          ),

          // Bookmark list
          Expanded(
            child: Obx(() {
              final bookmarks = controller.allBookmarks;

              if (bookmarks.isEmpty) {
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
                        controller.searchQuery.value.isNotEmpty
                            ? '没有找到相关标记'
                            : '暂无视频标记',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.searchQuery.value.isNotEmpty
                            ? '尝试其他关键词'
                            : '在视频播放时点击标记图标添加',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Group by video if sorted by video name
              if (controller.sortType.value == SortType.videoName) {
                final grouped = <String, List<VideoBookmark>>{};
                for (final bookmark in bookmarks) {
                  grouped.putIfAbsent(bookmark.videoTitle, () => []).add(bookmark);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final videoTitle = grouped.keys.elementAt(index);
                    final videoBookmarks = grouped[videoTitle]!;
                    final firstBvid = videoBookmarks.first.bvid;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  videoTitle,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Get.toNamed('/video', arguments: {
                                    'bvid': firstBvid,
                                    'heroTag': Utils.makeHeroTag(firstBvid),
                                  });
                                },
                                child: const Text('查看视频'),
                              ),
                            ],
                          ),
                        ),
                        ...videoBookmarks.map((bookmark) => _buildBookmarkTile(bookmark)),
                        const Divider(),
                      ],
                    );
                  },
                );
              }

              // Regular list view
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  return _buildBookmarkTile(bookmarks[index]);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkTile(VideoBookmark bookmark) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showBookmarkOptions(bookmark),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bookmark.note != null && bookmark.note!.isNotEmpty)
              Text(
                bookmark.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            Text(
              bookmark.videoTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
