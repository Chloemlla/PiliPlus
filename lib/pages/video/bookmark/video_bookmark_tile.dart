import 'package:flutter/material.dart';
import 'package:pili_plus/models/video_bookmark.dart';

class VideoBookmarkTile extends StatelessWidget {
  const VideoBookmarkTile({
    super.key,
    required this.bookmark,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.showVideoTitle = true,
    this.useCard = true,
  });

  final VideoBookmark bookmark;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showVideoTitle;
  final bool useCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = ListTile(
      onTap: onTap,
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
      subtitle: _buildSubtitle(theme),
      trailing: PopupMenuButton<_BookmarkTileAction>(
        onSelected: (action) {
          switch (action) {
            case _BookmarkTileAction.edit:
              onEdit();
            case _BookmarkTileAction.delete:
              onDelete();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _BookmarkTileAction.edit,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.edit_outlined, size: 18),
              title: Text('编辑'),
            ),
          ),
          PopupMenuItem(
            value: _BookmarkTileAction.delete,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outlined,
                size: 18,
                color: theme.colorScheme.error,
              ),
              title: Text(
                '删除',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );

    if (!useCard) {
      return tile;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: tile,
    );
  }

  Widget? _buildSubtitle(ThemeData theme) {
    final hasNote = bookmark.note?.isNotEmpty == true;
    if (!hasNote && !showVideoTitle) {
      return null;
    }
    if (!showVideoTitle) {
      return Text(
        bookmark.note!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasNote)
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
    );
  }
}

enum _BookmarkTileAction {
  edit,
  delete,
}
