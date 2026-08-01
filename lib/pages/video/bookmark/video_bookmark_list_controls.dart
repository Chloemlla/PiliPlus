import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/controllers/video_bookmark_controller.dart';
import 'package:pili_plus/services/video_bookmark_service.dart';

void showVideoBookmarkSortSheet({
  required BuildContext context,
  required VideoBookmarkController controller,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sortTile(
            context: sheetContext,
            controller: controller,
            type: SortType.mostRecent,
            icon: Icons.access_time,
            label: '最近添加',
          ),
          _sortTile(
            context: sheetContext,
            controller: controller,
            type: SortType.videoName,
            icon: Icons.video_library,
            label: '按视频名称',
          ),
          _sortTile(
            context: sheetContext,
            controller: controller,
            type: SortType.timestamp,
            icon: Icons.timer,
            label: '按时间戳',
          ),
        ],
      ),
    ),
  );
}

Widget _sortTile({
  required BuildContext context,
  required VideoBookmarkController controller,
  required SortType type,
  required IconData icon,
  required String label,
}) {
  return ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: controller.sortType.value == type
        ? const Icon(Icons.check)
        : null,
    onTap: () {
      controller.setSortType(type);
      Navigator.pop(context);
    },
  );
}

void showVideoBookmarkFilterSheet({
  required BuildContext context,
  required VideoBookmarkController controller,
  String? currentBvid,
}) {
  final authorMids = controller.availableAuthorMids;
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.65,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Obx(
              () => ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('全部标记'),
                trailing: controller.filterType.value == BookmarkFilterType.all
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  controller.clearFilter();
                  Navigator.pop(sheetContext);
                },
              ),
            ),
            if (currentBvid != null)
              Obx(
                () => ListTile(
                  leading: const Icon(Icons.smart_display_outlined),
                  title: const Text('当前视频'),
                  trailing:
                      controller.filterType.value ==
                              BookmarkFilterType.currentVideo &&
                          controller.bvidFilter.value == currentBvid
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    controller.filterByCurrentVideo(currentBvid);
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
            if (authorMids.isNotEmpty) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('按创作者筛选'),
              ),
              for (final authorMid in authorMids)
                Obx(
                  () => ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('UID $authorMid'),
                    trailing:
                        controller.filterType.value ==
                                BookmarkFilterType.creator &&
                            controller.authorMidFilter.value == authorMid
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () {
                      controller.filterByCreator(authorMid);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
