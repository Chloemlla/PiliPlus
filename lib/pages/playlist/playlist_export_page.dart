import 'dart:convert';
import 'dart:typed_data';

import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models_new/fav/fav_folder/list.dart';
import 'package:pili_plus/pages/playlist/widgets/favorite_folder_selector.dart';
import 'package:pili_plus/services/playlist_export_service.dart';
import 'package:pili_plus/utils/storage_utils.dart';
import 'package:pili_plus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderBox;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

enum ExportFormat { json, m3u8 }

class PlaylistExportPage extends StatefulWidget {
  const PlaylistExportPage({super.key});

  @override
  State<PlaylistExportPage> createState() => _PlaylistExportPageState();
}

class _PlaylistExportPageState extends State<PlaylistExportPage> {
  ExportFormat _selectedFormat = ExportFormat.json;
  final Set<int> _selectedFavoriteIds = <int>{};
  List<FavFolderInfo> _favoriteFolders = <FavFolderInfo>[];
  String? _favoriteLoadError;
  bool _isLoadingFavorites = true;
  bool _includeWatchLater = false;
  bool _includeBangumi = false;
  bool _includeCinema = false;
  bool _isExporting = false;

  bool get _hasSelection =>
      _selectedFavoriteIds.isNotEmpty ||
      _includeWatchLater ||
      _includeBangumi ||
      _includeCinema;

  @override
  void initState() {
    super.initState();
    _loadFavoriteFolders();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出播放列表'),
        actions: [
          TextButton(
            onPressed: _isExporting || !_hasSelection
                ? null
                : () => _export(toFile: true),
            child: _isExporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('导出'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('导出格式', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ExportFormat>(
            segments: const [
              ButtonSegment(
                value: ExportFormat.json,
                label: Text('JSON'),
                icon: Icon(Icons.code),
              ),
              ButtonSegment(
                value: ExportFormat.m3u8,
                label: Text('M3U8'),
                icon: Icon(Icons.playlist_play),
              ),
            ],
            selected: {_selectedFormat},
            onSelectionChanged: _isExporting
                ? null
                : (selected) {
                    setState(() => _selectedFormat = selected.first);
                  },
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFormat == ExportFormat.json
                ? 'JSON 包含完整元数据，可再次导入视频条目'
                : 'M3U8 使用稳定的 BVID/season 页面引用，避免写入会过期的播放地址',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('选择内容', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          FavoriteFolderSelector(
            folders: _favoriteFolders,
            selectedIds: _selectedFavoriteIds,
            loadError: _favoriteLoadError,
            isLoading: _isLoadingFavorites,
            enabled: !_isExporting,
            onRetry: _loadFavoriteFolders,
            onChanged: (folderId, selected) {
              setState(() {
                if (selected) {
                  _selectedFavoriteIds.add(folderId);
                } else {
                  _selectedFavoriteIds.remove(folderId);
                }
              });
            },
          ),
          CheckboxListTile(
            value: _includeWatchLater,
            onChanged: _isExporting
                ? null
                : (value) {
                    setState(() => _includeWatchLater = value ?? false);
                  },
            title: const Text('稍后再看'),
            secondary: const Icon(Icons.watch_later_outlined),
          ),
          CheckboxListTile(
            value: _includeBangumi,
            onChanged: _isExporting
                ? null
                : (value) {
                    setState(() => _includeBangumi = value ?? false);
                  },
            title: const Text('追番'),
            subtitle: const Text('备份为 season 引用'),
            secondary: const Icon(Icons.live_tv_outlined),
          ),
          CheckboxListTile(
            value: _includeCinema,
            onChanged: _isExporting
                ? null
                : (value) {
                    setState(() => _includeCinema = value ?? false);
                  },
            title: const Text('追剧'),
            subtitle: const Text('备份为 season 引用'),
            secondary: const Icon(Icons.movie_outlined),
          ),
          const SizedBox(height: 8),
          Text(
            '选择多个来源时会合并到同一个文件。追番/追剧可以备份和分享，但不会作为视频导入。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('导出方式', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            enabled: !_isExporting && _hasSelection,
            leading: const Icon(Icons.save_outlined),
            title: const Text('保存到本地'),
            subtitle: const Text('选择保存位置并写入文件'),
            onTap: () => _export(toFile: true),
          ),
          ListTile(
            enabled: !_isExporting && _hasSelection,
            leading: const Icon(Icons.share_outlined),
            title: const Text('分享'),
            subtitle: const Text('通过系统分享当前格式的文件'),
            onTap: () => _export(share: true),
          ),
          ListTile(
            enabled: !_isExporting && _hasSelection,
            leading: const Icon(Icons.copy_outlined),
            title: const Text('复制内容'),
            subtitle: const Text('复制当前格式的文本内容'),
            onTap: () => _export(copyToClipboard: true),
          ),
        ],
      ),
    );
  }

  Future<void> _loadFavoriteFolders() async {
    if (mounted) {
      setState(() {
        _isLoadingFavorites = true;
        _favoriteLoadError = null;
      });
    }

    final result = await PlaylistExportService.getFavoriteFolders();
    if (!mounted) {
      return;
    }
    if (result case Success(:final response)) {
      setState(() {
        _favoriteFolders = response;
        _selectedFavoriteIds.retainAll(
          response.map((folder) => folder.id).toSet(),
        );
        _isLoadingFavorites = false;
      });
    } else {
      setState(() {
        _favoriteLoadError = result.toString();
        _isLoadingFavorites = false;
      });
    }
  }

  Future<void> _export({
    bool toFile = false,
    bool share = false,
    bool copyToClipboard = false,
  }) async {
    if (!_hasSelection) {
      SmartDialog.showToast('请选择要导出的内容');
      return;
    }

    setState(() => _isExporting = true);
    try {
      final favoriteLists = <int, String>{
        for (final folder in _favoriteFolders)
          if (_selectedFavoriteIds.contains(folder.id)) folder.id: folder.title,
      };
      final result = await PlaylistExportService.exportMultiplePlaylists(
        favoriteLists: favoriteLists,
        includeWatchLater: _includeWatchLater,
        includeBangumi: _includeBangumi,
        includeCinema: _includeCinema,
      );
      if (result case Success(:final response)) {
        final isJson = _selectedFormat == ExportFormat.json;
        final content = isJson
            ? PlaylistExportService.exportAsJson(response)
            : PlaylistExportService.exportAsM3U8(response);
        final extension = isJson ? 'json' : 'm3u8';
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final fileName = 'PiliPlus_playlist_$timestamp.$extension';
        final bytes = Uint8List.fromList(utf8.encode(content));

        if (copyToClipboard) {
          await Utils.copyText(content, toastText: '播放列表内容已复制');
        } else if (share) {
          if (!mounted) {
            return;
          }
          await _shareFile(
            bytes: bytes,
            fileName: fileName,
            mimeType: isJson
                ? 'application/json'
                : 'application/vnd.apple.mpegurl',
          );
        } else if (toFile) {
          await StorageUtils.saveBytes2File(
            name: fileName,
            bytes: bytes,
            allowedExtensions: [extension],
          );
        }
      } else {
        final message = result.toString();
        SmartDialog.showToast(message.isEmpty ? '导出失败' : message);
      }
    } catch (error) {
      SmartDialog.showToast('导出失败: $error');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final renderObject = context.findRenderObject();
    final sharePositionOrigin =
        renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
        subject: 'PiliPlus 播放列表导出',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}
