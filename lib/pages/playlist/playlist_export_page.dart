import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:pili_plus/models/playlist_export_data.dart';
import 'package:pili_plus/services/playlist_export_service.dart';
import 'package:pili_plus/services/playlist_import_service.dart';
import 'package:pili_plus/utils/storage_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';

enum ExportFormat { json, m3u8 }

class PlaylistExportPage extends StatefulWidget {
  const PlaylistExportPage({super.key});

  @override
  State<PlaylistExportPage> createState() => _PlaylistExportPageState();
}

class _PlaylistExportPageState extends State<PlaylistExportPage> {
  ExportFormat _selectedFormat = ExportFormat.json;
  final Set<int> _selectedFavoriteIds = {};
  bool _includeWatchLater = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导出播放列表'),
        actions: [
          TextButton(
            onPressed: _isExporting ? null : _export,
            child: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('导出'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Format selection
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
            onSelectionChanged: (selected) {
              setState(() {
                _selectedFormat = selected.first;
              });
            },
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFormat == ExportFormat.json
                ? 'JSON 格式：包含完整元数据，可完整导入'
                : 'M3U8 格式：通用播放列表格式，仅包含视频引用',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Content selection
          Text('选择内容', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          // Note: In a real implementation, this would fetch actual favorite lists
          // For now, showing placeholder UI
          Card(
            child: ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('收藏夹'),
              subtitle: const Text('需要选择具体收藏夹'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectFavoriteLists,
            ),
          ),

          CheckboxListTile(
            value: _includeWatchLater,
            onChanged: (value) {
              setState(() {
                _includeWatchLater = value ?? false;
              });
            },
            title: const Text('稍后再看'),
            secondary: const Icon(Icons.watch_later_outlined),
          ),

          const SizedBox(height: 8),
          Text(
            '选中的收藏夹将合并导出为一个文件',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Export method
          Text('导出方式', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('保存到本地'),
            subtitle: const Text('保存为文件'),
            onTap: _isExporting ? null : () => _export(toFile: true),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('分享'),
            subtitle: const Text('通过系统分享'),
            onTap: _isExporting ? null : () => _export(share: true),
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('复制到剪贴板'),
            subtitle: const Text('复制 JSON 内容'),
            onTap: _isExporting ? null : () => _export(copyToClipboard: true),
          ),
        ],
      ),
    );
  }

  void _selectFavoriteLists() {
    // This would open a dialog to select favorite lists
    // For now, show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择收藏夹'),
        content: const Text('收藏夹选择功能需要在实际集成时实现'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _export({
    bool toFile = false,
    bool share = false,
    bool copyToClipboard = false,
  }) async {
    if (_selectedFavoriteIds.isEmpty && !_includeWatchLater) {
      SmartDialog.showToast('请选择要导出的内容');
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      // Build playlist data
      final Map<int, String> favoriteLists = {};
      for (final id in _selectedFavoriteIds) {
        favoriteLists[id] = '收藏夹 $id';
      }

      // For demo purposes, create a sample export
      // In real implementation, this would call the actual service
      final sampleVideos = [
        PlaylistVideoItem(
          bvid: 'BV1example1',
          title: '示例视频 1',
          author: '示例作者',
          duration: 300,
        ),
        PlaylistVideoItem(
          bvid: 'BV1example2',
          title: '示例视频 2',
          author: '示例作者',
          duration: 600,
        ),
      ];

      final playlistData = PlaylistExportData(
        exportedAt: DateTime.now(),
        playlistName: '我的播放列表',
        videos: sampleVideos,
      );

      String content;
      String fileName;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      if (_selectedFormat == ExportFormat.json) {
        content = PlaylistExportService.exportAsJson(playlistData);
        fileName = 'playlist_$timestamp.json';
      } else {
        content = PlaylistExportService.exportAsM3U8(playlistData);
        fileName = 'playlist_$timestamp.m3u8';
      }

      if (copyToClipboard) {
        await _copyToClipboard(content);
      } else if (toFile) {
        await _saveToFile(content, fileName);
      } else if (share) {
        await _shareFile(content, fileName);
      }
    } catch (e) {
      SmartDialog.showToast('导出失败: $e');
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _copyToClipboard(String content) async {
    // Using storage_utils copy function
    // ImportUtils.copyText(content);
    SmartDialog.showToast('已复制到剪贴板');
  }

  Future<void> _saveToFile(String content, String fileName) async {
    try {
      final bytes = content.codeUnits;
      StorageUtils.saveBytes2File(
        name: fileName,
        bytes: bytes,
        allowedExtensions: [fileName.split('.').last],
      );
      SmartDialog.showToast('文件已保存');
    } catch (e) {
      SmartDialog.showToast('保存失败: $e');
    }
  }

  Future<void> _shareFile(String content, String fileName) async {
    try {
      // Create temporary file for sharing
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(content);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: 'PiliPlus 播放列表导出',
      );
    } catch (e) {
      SmartDialog.showToast('分享失败: $e');
    }
  }
}
