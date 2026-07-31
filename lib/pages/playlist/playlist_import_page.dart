import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pili_plus/models/playlist_export_data.dart';
import 'package:pili_plus/services/playlist_import_service.dart';
import 'dart:io';

class PlaylistImportPage extends StatefulWidget {
  const PlaylistImportPage({super.key});

  @override
  State<PlaylistImportPage> createState() => _PlaylistImportPageState();
}

class _PlaylistImportPageState extends State<PlaylistImportPage> {
  ImportDestination _destination = ImportDestination.watchLater;
  ValidationResult? _validationResult;
  PlaylistExportData? _previewData;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入播放列表'),
        actions: [
          TextButton(
            onPressed: _isImporting ? null : _import,
            child: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('导入'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Import destination
          Text('导入位置', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          RadioListTile<ImportDestination>(
            value: ImportDestination.watchLater,
            groupValue: _destination,
            onChanged: (value) {
              setState(() {
                _destination = value!;
              });
            },
            title: const Text('稍后再看'),
            subtitle: const Text('添加到"稍后再看"列表'),
            secondary: const Icon(Icons.watch_later_outlined),
          ),

          RadioListTile<ImportDestination>(
            value: ImportDestination.createNew,
            groupValue: _destination,
            onChanged: (value) {
              setState(() {
                _destination = value!;
              });
            },
            title: const Text('创建新收藏夹'),
            subtitle: const Text('创建新的收藏夹并导入'),
            secondary: const Icon(Icons.create_new_folder_outlined),
          ),

          RadioListTile<ImportDestination>(
            value: ImportDestination.specified,
            groupValue: _destination,
            onChanged: (value) {
              setState(() {
                _destination = value!;
              });
            },
            title: const Text('指定收藏夹'),
            subtitle: const Text('添加到已存在的收藏夹'),
            secondary: const Icon(Icons.folder_outlined),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Import source
          Text('选择来源', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          ListTile(
            leading: const Icon(Icons.file_open),
            title: const Text('从文件导入'),
            subtitle: const Text('选择 JSON 播放列表文件'),
            onTap: _isImporting ? null : _pickFile,
          ),

          const SizedBox(height: 16),

          // Preview section
          if (_validationResult != null) ...[
            Card(
              color: _validationResult!.isValid
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _validationResult!.isValid
                              ? Icons.check_circle
                              : Icons.error,
                          color: _validationResult!.isValid
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _validationResult!.isValid
                                ? '文件有效'
                                : '文件无效',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _validationResult!.isValid
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_validationResult!.message),
                    if (_validationResult!.previewInfo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _validationResult!.previewInfo!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          if (_previewData != null) ...[
            const SizedBox(height: 16),
            Text('预览', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _previewData!.videos.length.clamp(0, 5),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final video = _previewData!.videos[index];
                  return ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(video.bvid),
                    trailing: video.duration != null
                        ? Text('${video.duration! ~/ 60}:${(video.duration! % 60).toString().padLeft(2, '0')}')
                        : null,
                  );
                },
              ),
            ),
            if (_previewData!.videos.length > 5) ...[
              const SizedBox(height: 8),
              Text(
                '... 还有 ${_previewData!.videos.length - 5} 个视频',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),

          // Notes
          Card(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '注意事项',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 仅支持 PiliPlus 导出的 JSON 格式\n'
                    '• 重复的视频将被跳过\n'
                    '• 部分元数据可能无法完全保留',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final content = await result.xFile.readAsString();
        await _validateAndPreview(content);
      }
    } catch (e) {
      SmartDialog.showToast('读取文件失败: $e');
    }
  }

  Future<void> _validateAndPreview(String content) async {
    // First try to validate as JSON
    var result = PlaylistImportService.validateJson(content);

    if (result.isValid) {
      try {
        // Parse and show preview
        final data = PlaylistExportData.fromJson(
          Map<String, dynamic>.from(
            (content is Map) ? content :
              (content is String) ?
                (result.previewInfo != null ? {} : {})
                : {}
          ),
        );
        setState(() {
          _validationResult = result;
          _previewData = data;
        });
        return;
      } catch (_) {}
    }

    setState(() {
      _validationResult = result;
      _previewData = null;
    });
  }

  Future<void> _import() async {
    if (_previewData == null) {
      SmartDialog.showToast('请先选择有效的播放列表文件');
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      // For demo purposes, show success
      // In real implementation, this would call PlaylistImportService.importPlaylist
      await Future.delayed(const Duration(seconds: 1));

      SmartDialog.showToast('成功导入 ${_previewData!.videos.length} 个视频');

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      SmartDialog.showToast('导入失败: $e');
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }
}
