import 'package:pili_plus/common/widgets/favorite_sort_page.dart';
import 'package:pili_plus/common/widgets/image/network_img_layer.dart';
import 'package:pili_plus/pages/fav/video/controller.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/utils.dart';
import 'package:flutter/material.dart';

/// Local pin + drag-sort overlay for the favorite folder list. The display
/// order (pinned first) is persisted through [GStorage.favoriteOrderStore] and
/// can be exported/restored.
class FavFolderSortPage extends StatefulWidget {
  const FavFolderSortPage({super.key, required this.favController});

  final FavController favController;

  @override
  State<FavFolderSortPage> createState() => _FavFolderSortPageState();
}

class _FavFolderSortPageState extends State<FavFolderSortPage> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.favController;
    return FavoriteSortPage(
      title: '收藏夹排序',
      scope: FavController.scope,
      store: GStorage.favoriteOrderStore,
      allIds: controller.orderedFolders.map(FavController.folderId).toList(),
      itemBuilder: (context, id) {
        final folder = controller.orderedFolders.firstWhere(
          (folder) => FavController.folderId(folder) == id,
        );
        return ListTile(
          dense: true,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: NetworkImgLayer(
              width: 56,
              height: 40,
              src: folder.cover,
            ),
          ),
          title: Text(
            folder.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${folder.mediaCount}个内容',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
      onExport: () => Utils.jsonEncoder.convert(
        GStorage.favoriteOrderStore.exportState(FavController.scope),
      ),
      onImport: (json) async {
        await GStorage.favoriteOrderStore.importState(FavController.scope, json);
      },
      onChanged: controller.loadingState.refresh,
      exportFileName: 'fav_folder_order',
      exportTitle: '收藏夹排序状态',
    );
  }
}
