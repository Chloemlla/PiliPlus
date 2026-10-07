import 'package:pili_plus/common/widgets/loading_widget/http_error.dart';
import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models_new/download/bili_download_entry_info.dart';
import 'package:pili_plus/pages/common/multi_select/base.dart';
import 'package:pili_plus/pages/common/search/common_search_page.dart';
import 'package:pili_plus/pages/download/detail/widgets/item.dart';
import 'package:pili_plus/pages/download/download_action_mixin.dart';
import 'package:pili_plus/pages/download/search/controller.dart';
import 'package:pili_plus/services/download/download_service.dart';
import 'package:pili_plus/utils/grid.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

class DownloadSearchPage extends StatefulWidget {
  const DownloadSearchPage({
    super.key,
    required this.progress,
  });

  final ChangeNotifier progress;

  @override
  State<DownloadSearchPage> createState() => _DownloadSearchPageState();
}

class _DownloadSearchPageState
    extends
        CommonSearchPageState<
          DownloadSearchPage,
          List<BiliDownloadEntryInfo>,
          BiliDownloadEntryInfo
        >
    with
        GridMixin,
        BaseDownloadActionMixin<DownloadSearchPage, BiliDownloadEntryInfo>,
        CommonDownloadActionMixin<DownloadSearchPage> {
  @override
  DownloadSearchController controller = Get.put(DownloadSearchController());

  @override
  final downloadService = Get.find<DownloadService>();

  @override
  BaseMultiSelectMixin<BiliDownloadEntryInfo> get multiSelectCtr => controller;

  @override
  List<Widget>? get extraActions => [
    IconButton(
      tooltip: '多选',
      onPressed: () {
        if (controller.loadingState.value is! Success) {
          return;
        }
        if (controller.enableMultiSelect.value) {
          controller.handleSelect();
        } else {
          controller.enableMultiSelect.value = true;
        }
      },
      icon: const Icon(Icons.edit_note),
    ),
  ];

  @override
  List<Widget>? get multiSelectActions => [updateBtn()];

  @override
  Widget buildList(List<BiliDownloadEntryInfo> list) {
    if (list.isNotEmpty) {
      return SliverGrid.builder(
        gridDelegate: gridDelegate,
        itemBuilder: (context, index) {
          final entry = list[index];
          return DetailItem(
            entry: entry,
            progress: widget.progress,
            downloadService: downloadService,
            showTitle: true,
            onDelete: () => controller.onRemoveSingle(index, entry),
            controller: controller,
          );
        },
        itemCount: list.length,
      );
    }
    return const HttpError();
  }
}
