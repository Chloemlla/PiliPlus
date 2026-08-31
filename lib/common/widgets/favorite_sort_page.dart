import 'package:pili_plus/common/widgets/dialog/export_import.dart';
import 'package:pili_plus/common/widgets/reorder_mixin.dart';
import 'package:pili_plus/utils/storage/favorite_order_store.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pili_plus/common/widgets/scaffold/simple_scaffold.dart';

/// Generic local drag-sort page that persists pin + order through
/// [FavoriteOrderStore]. Rows reorder freely by long-press; the leading pin
/// button pins/unpins a row; pinned rows always render first.
class FavoriteSortPage extends StatefulWidget {
  const FavoriteSortPage({
    super.key,
    required this.title,
    required this.scope,
    required this.store,
    required this.allIds,
    required this.itemBuilder,
    this.onExport,
    this.onImport,
    this.onChanged,
    this.exportFileName = 'favorite_order',
    this.exportTitle = '排序状态',
  });

  final String title;
  final String scope;
  final FavoriteOrderStore store;

  /// Every available id (display order is derived from the store).
  final List<String> allIds;

  final Widget Function(BuildContext context, String id) itemBuilder;

  /// When both [onExport] and [onImport] are provided an import/export button
  /// is shown in the app bar.
  final ValueGetter<String>? onExport;
  final Future<void> Function(Object? json)? onImport;

  /// Notifies the caller after every reorder/pin/import.
  final VoidCallback? onChanged;

  final String exportFileName;
  final String exportTitle;

  @override
  State<FavoriteSortPage> createState() => _FavoriteSortPageState();
}

class _FavoriteSortPageState extends State<FavoriteSortPage>
    with ReorderMixin {
  late List<String> _ids;

  FavoriteOrderStore get _store => widget.store;
  String get _scope => widget.scope;

  @override
  void initState() {
    super.initState();
    _ids = _store.displayOrder(_scope, widget.allIds);
  }

  void _refresh() {
    setState(() {
      _ids = _store.displayOrder(_scope, widget.allIds);
    });
    widget.onChanged?.call();
  }

  Future<void> _onReorderItem(int oldIndex, int newIndex) async {
    await _store.applyDrag(_scope, oldIndex, newIndex, widget.allIds);
    _refresh();
  }

  Future<void> _togglePin(String id) async {
    if (_store.isPinned(_scope, id)) {
      await _store.unpin(_scope, id);
    } else {
      await _store.pin(_scope, id, widget.allIds);
    }
    _refresh();
  }

  void _showImportExport() {
    showImportExportDialog<Object?>(
      context,
      title: widget.exportTitle,
      onExport: widget.onExport!,
      onImport: (json) async {
        await widget.onImport!(json);
        _refresh();
      },
      localFileName: () => widget.exportFileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTransfer = widget.onExport != null && widget.onImport != null;
    return SimpleScaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (hasTransfer)
            IconButton(
              tooltip: '导入/导出排序',
              onPressed: _showImportExport,
              icon: const Icon(Icons.sync_alt_outlined),
            ),
          TextButton(
            onPressed: Get.back,
            child: const Text('完成'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildBody,
    );
  }

  Widget get _buildBody {
    final scheme = ColorScheme.of(context);
    return ReorderableListView.builder(
      onReorderItem: _onReorderItem,
      proxyDecorator: proxyDecorator,
      physics: const AlwaysScrollableScrollPhysics(),
      padding:
          MediaQuery.viewPaddingOf(context).copyWith(top: 0) +
          const EdgeInsets.only(bottom: 100),
      itemCount: _ids.length,
      itemBuilder: (context, index) {
        final id = _ids[index];
        final pinned = _store.isPinned(_scope, id);
        return Padding(
          key: ValueKey(id),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                tooltip: pinned ? '取消置顶' : '置顶',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 20,
                  color: pinned ? scheme.primary : scheme.outline,
                ),
                onPressed: () => _togglePin(id),
              ),
              Expanded(child: widget.itemBuilder(context, id)),
            ],
          ),
        );
      },
    );
  }
}
