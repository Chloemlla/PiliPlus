import 'package:pili_plus/models_new/fav/fav_folder/list.dart';
import 'package:flutter/material.dart';

typedef FavoriteFolderSelectionChanged =
    void Function(
      int folderId,
      bool selected,
    );

class FavoriteFolderSelector extends StatelessWidget {
  final List<FavFolderInfo> folders;
  final Set<int> selectedIds;
  final String? loadError;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onRetry;
  final FavoriteFolderSelectionChanged onChanged;

  const FavoriteFolderSelector({
    super.key,
    required this.folders,
    required this.selectedIds,
    required this.loadError,
    required this.isLoading,
    required this.enabled,
    required this.onRetry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isLoading) {
      return const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('正在读取收藏夹'),
        ),
      );
    }
    if (loadError case final error?) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
          title: const Text('收藏夹读取失败'),
          subtitle: Text(error),
          trailing: IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            tooltip: '重试',
          ),
        ),
      );
    }
    if (folders.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.bookmark_outline),
          title: Text('收藏夹'),
          subtitle: Text('当前账号没有可导出的收藏夹'),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.bookmark_outline),
        title: const Text('收藏夹'),
        subtitle: Text(
          selectedIds.isEmpty ? '选择一个或多个收藏夹' : '已选择 ${selectedIds.length} 个收藏夹',
        ),
        children: [
          for (final folder in folders)
            CheckboxListTile(
              value: selectedIds.contains(folder.id),
              onChanged: enabled
                  ? (selected) => onChanged(folder.id, selected ?? false)
                  : null,
              title: Text(folder.title),
              subtitle: Text('${folder.mediaCount} 个条目'),
              secondary: const Icon(Icons.folder_outlined),
            ),
        ],
      ),
    );
  }
}
