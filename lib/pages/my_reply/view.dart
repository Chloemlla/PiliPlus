import 'package:pili_plus/common/widgets/dialog/dialog.dart';
import 'package:pili_plus/common/widgets/dialog/export_import.dart';
import 'package:pili_plus/common/widgets/loading_widget/http_error.dart';
import 'package:pili_plus/common/widgets/view_sliver_safe_area.dart';
import 'package:pili_plus/grpc/bilibili/main/community/reply/v1.pb.dart'
    show ReplyInfo;
import 'package:pili_plus/pages/my_reply/controller.dart';
import 'package:pili_plus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:pili_plus/utils/app_scheme.dart';
import 'package:pili_plus/utils/id_utils.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:pili_plus/utils/reply_utils.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:pili_plus/utils/waterfall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class MyReply extends StatefulWidget {
  const MyReply({super.key});

  @override
  State<MyReply> createState() => _MyReplyState();
}

class _MyReplyState extends State<MyReply> with DynMixin {
  late final MyReplyController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MyReplyController(GStorage.favoriteReplyStore)..reload();
    if (_controller.invalidStoredCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          SmartDialog.showToast(
            '已跳过 ${_controller.invalidStoredCount} 条损坏的本地收藏',
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final replies = _controller.replies;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('收藏的评论（${_controller.count}）'),
        actions: [
          IconButton(
            tooltip: '清空收藏',
            onPressed: _controller.count == 0 ? null : _clearFavorites,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          IconButton(
            tooltip: '导出',
            onPressed: _showExportDialog,
            icon: const Icon(Icons.file_upload_outlined),
          ),
          IconButton(
            tooltip: '导入',
            onPressed: _showImportDialog,
            icon: const Icon(Icons.file_download_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          replies.isNotEmpty
              ? ViewSliverSafeArea(
                  sliver: SliverWaterfallFlow(
                    gridDelegate: dynGridDelegate,
                    delegate: SliverChildBuilderDelegate(
                      childCount: _controller.count,
                      (context, index) => ReplyItemGrpc(
                        replyLevel: 0,
                        needDivider: false,
                        replyItem: replies[index],
                        replyReply: _replyReply,
                        onDelete: (reply, _) => _onDelete(reply),
                        onCheckReply: _onCheckReply,
                      ),
                    ),
                  ),
                )
              : const HttpError(
                  errMsg: '暂无收藏的评论\n可在评论更多菜单中收藏',
                ),
        ],
      ),
    );
  }

  void _replyReply(ReplyInfo replyInfo, int? rpid) {
    switch (replyInfo.type.toInt()) {
      case 1:
        PiliScheme.videoPush(
          replyInfo.oid.toInt(),
          null,
        );
      case 12:
        PageUtils.toDupNamed(
          '/articlePage',
          parameters: {
            'id': replyInfo.oid.toString(),
            'type': 'read',
          },
        );
      case _:
        PageUtils.pushDynFromId(
          rid: replyInfo.oid.toString(),
          type: replyInfo.type,
        );
    }
  }

  Future<void> _onDelete(ReplyInfo reply) async {
    await _controller.delete(reply.id.toString());
    if (mounted) {
      setState(() {});
    }
  }

  void _onCheckReply(ReplyInfo replyInfo) {
    final oid = replyInfo.oid.toInt();
    ReplyUtils.onCheckReply(
      replyInfo: replyInfo,
      biliSendCommAntifraud: Pref.biliSendCommAntifraud,
      sourceId: switch (oid) {
        1 => IdUtils.av2bv(oid),
        _ => oid.toString(),
      },
      isManual: true,
    );
  }

  String _onExport() {
    return _controller.exportJson();
  }

  void _showExportDialog() {
    const style = TextStyle(fontSize: 14);
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        clipBehavior: .hardEdge,
        contentPadding: const .symmetric(vertical: 12),
        children: [
          ListTile(
            dense: true,
            title: const Text('导出至剪贴板', style: style),
            onTap: () {
              Get.back();
              exportToClipBoard(onExport: _onExport);
            },
          ),
          ListTile(
            dense: true,
            title: const Text('导出文件至本地', style: style),
            onTap: () {
              Get.back();
              exportToLocalFile(
                onExport: _onExport,
                localFileName: () => 'reply',
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _onImport(Object? value) async {
    final summary = await _controller.importJson(value);
    if (!mounted) return;
    setState(() {});
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入摘要'),
        content: Text(summary.message),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    const style = TextStyle(fontSize: 14);
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        clipBehavior: .hardEdge,
        contentPadding: const .symmetric(vertical: 12),
        children: [
          ListTile(
            dense: true,
            title: const Text('从剪贴板导入', style: style),
            onTap: () {
              Get.back();
              importFromClipBoard<Object?>(
                context,
                title: '评论',
                onExport: _onExport,
                onImport: _onImport,
                showConfirmDialog: false,
              );
            },
          ),
          ListTile(
            dense: true,
            title: const Text('从本地文件导入', style: style),
            onTap: () {
              Get.back();
              importFromLocalFile<Object?>(onImport: _onImport);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _clearFavorites() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: const Text('清空收藏的评论'),
      content: Text('确定清空全部 ${_controller.count} 条本地评论收藏吗？此操作无法撤销。'),
    );
    if (!confirmed) return;
    await _controller.clear();
    if (!mounted) return;
    setState(() {});
    SmartDialog.showToast('已清空收藏');
  }
}
