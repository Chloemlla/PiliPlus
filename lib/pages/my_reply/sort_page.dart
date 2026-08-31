import 'package:pili_plus/common/widgets/favorite_sort_page.dart';
import 'package:pili_plus/pages/my_reply/controller.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:flutter/material.dart';

/// Drag-sort + pin page for favorited comments. Backed by the shared
/// [FavoriteSortPage] overlay; exporting also carries the full comment data.
class MyReplySortPage extends StatefulWidget {
  const MyReplySortPage({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final MyReplyController controller;
  final VoidCallback? onChanged;

  @override
  State<MyReplySortPage> createState() => _MyReplySortPageState();
}

class _MyReplySortPageState extends State<MyReplySortPage> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return FavoriteSortPage(
      title: '评论排序',
      scope: MyReplyController.scope,
      store: GStorage.favoriteOrderStore,
      allIds: controller.displayIds,
      itemBuilder: (context, id) {
        final reply = controller.replies.firstWhere(
          (reply) => reply.id.toString() == id,
        );
        return ListTile(
          dense: true,
          title: Text(
            reply.content.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            reply.member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
      onExport: controller.exportJson,
      onImport: (json) async {
        await controller.importJson(json);
      },
      onChanged: widget.onChanged,
      exportFileName: 'reply',
      exportTitle: '评论排序状态',
    );
  }
}
