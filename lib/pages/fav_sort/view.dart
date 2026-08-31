import 'package:pili_plus/common/widgets/favorite_sort_page.dart';
import 'package:pili_plus/pages/fav_detail/controller.dart';
import 'package:pili_plus/pages/fav_detail/widget/fav_video_card.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/utils.dart';
import 'package:flutter/material.dart';

/// Local pin + drag-sort overlay for videos inside a favorite folder. The
/// display order (pinned first) is persisted through
/// [GStorage.favoriteOrderStore] per folder and can be exported/restored.
class FavSortPage extends StatefulWidget {
  const FavSortPage({super.key, required this.favDetailController});

  final FavDetailController favDetailController;

  @override
  State<FavSortPage> createState() => _FavSortPageState();
}

class _FavSortPageState extends State<FavSortPage> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.favDetailController;
    return FavoriteSortPage(
      title: '排序: ${controller.folderInfo.value.title}',
      scope: controller.scope,
      store: GStorage.favoriteOrderStore,
      allIds: controller.orderedItems.map(FavDetailController.itemId).toList(),
      itemBuilder: (context, id) {
        final item = controller.orderedItems.firstWhere(
          (item) => FavDetailController.itemId(item) == id,
        );
        return SizedBox(
          height: 110,
          child: FavVideoCardH(item: item),
        );
      },
      onExport: () => Utils.jsonEncoder.convert(
        GStorage.favoriteOrderStore.exportState(controller.scope),
      ),
      onImport: (json) async {
        await GStorage.favoriteOrderStore.importState(controller.scope, json);
      },
      onChanged: controller.loadingState.refresh,
      exportFileName: 'fav_video_order',
      exportTitle: '视频排序状态',
    );
  }
}
