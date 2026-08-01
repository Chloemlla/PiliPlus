import 'package:pili_plus/http/loading_state.dart';
import 'package:pili_plus/models/playlist_export_data.dart';
import 'package:pili_plus/services/playlist_import_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class PlaylistImportPage extends StatefulWidget {
  const PlaylistImportPage({super.key});

  @override
  State<PlaylistImportPage> createState() => _PlaylistImportPageState();
}

class _PlaylistImportPageState extends State<PlaylistImportPage> {
  ImportDestination _destination = ImportDestination.watchLater;
  ValidationResult? _validationResult;
  PlaylistExportData? _previewData;
  String? _sourceContent;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入播放列表'),
        actions: [
          TextButton(
            onPressed: _isImporting || _previewData == null ? null : _import,
            child: _isImporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('导入'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('导入位置', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<ImportDestination>(
            groupValue: _destination,
            onChanged: (value) {
              if (!_isImporting && value != null) {
                setState(() => _destination = value);
              }
            },
            child: const Column(
              children: [
                RadioListTile<ImportDestination>(
                  value: ImportDestination.watchLater,
                  title: Text('稍后再看'),
                  subtitle: Text('跳过当前稍后再看中已有的 BVID'),
                  secondary: Icon(Icons.watch_later_outlined),
                ),
                RadioListTile<ImportDestination>(
                  value: ImportDestination.importedFavorite,
                  title: Text('“已导入”收藏夹'),
                  subtitle: Text('自动创建或复用专用私密收藏夹，并跳过重复视频'),
                  secondary: Icon(Icons.folder_copy_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('选择来源', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            enabled: !_isImporting,
            leading: const Icon(Icons.file_open_outlined),
            title: const Text('从文件导入'),
            subtitle: const Text('选择 PiliPlus 导出的 JSON 文件'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickFile,
          ),
          const SizedBox(height: 16),
          if (_validationResult case final validation?)
            _buildValidationCard(theme, validation),
          if (_previewData case final preview?) ...[
            const SizedBox(height: 16),
            _buildPreview(theme, preview),
          ],
          const SizedBox(height: 24),
          Card(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
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
                    '• 仅支持 PiliPlus JSON 播放列表\n'
                    '• 文件内和目标列表中的重复 BVID 会被跳过\n'
                    '• 追番/追剧 season 条目仅用于备份，不会作为视频导入',
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

  Widget _buildValidationCard(
    ThemeData theme,
    ValidationResult validation,
  ) {
    final isValid = validation.isValid;
    return Card(
      color:
          (isValid
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.errorContainer)
              .withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isValid ? Icons.check_circle_outline : Icons.error_outline,
                  color: isValid
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isValid ? '文件有效' : '文件无效',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isValid
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(validation.message),
            if (validation.previewInfo case final previewInfo?) ...[
              const SizedBox(height: 4),
              Text(
                previewInfo,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme, PlaylistExportData preview) {
    final previewCount = preview.videos.length > 5 ? 5 : preview.videos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('预览', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: previewCount,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = preview.videos[index];
              return ListTile(
                leading: Icon(
                  item.isVideo
                      ? Icons.play_circle_outline
                      : Icons.live_tv_outlined,
                ),
                title: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(item.referenceLabel),
                trailing: switch (item.duration) {
                  final duration? => Text(_formatDuration(duration)),
                  null => null,
                },
              );
            },
          ),
        ),
        if (preview.videos.length > previewCount) ...[
          const SizedBox(height: 8),
          Text(
            '还有 ${preview.videos.length - previewCount} 个条目未显示',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (result == null) {
        return;
      }
      final fileLength = await result.xFile.length();
      if (fileLength > PlaylistImportService.maxImportFileBytes) {
        if (!mounted) {
          return;
        }
        setState(() {
          _sourceContent = null;
          _previewData = null;
          _validationResult = const ValidationResult(
            isValid: false,
            message: '播放列表文件过大（最大 8 MiB）',
          );
        });
        return;
      }
      final content = await result.xFile.readAsString();
      if (!mounted) {
        return;
      }
      _validateAndPreview(content);
    } catch (error) {
      SmartDialog.showToast('读取文件失败: $error');
    }
  }

  void _validateAndPreview(String content) {
    final validation = PlaylistImportService.validateJson(content);
    setState(() {
      _sourceContent = validation.isValid ? content : null;
      _validationResult = validation;
      _previewData = validation.playlistData;
    });
  }

  Future<void> _import() async {
    final sourceContent = _sourceContent;
    if (sourceContent == null) {
      SmartDialog.showToast('请先选择有效的播放列表文件');
      return;
    }

    setState(() => _isImporting = true);
    try {
      final result = await PlaylistImportService.importPlaylist(
        jsonString: sourceContent,
        destination: _destination,
      );
      if (result case Success(:final response)) {
        SmartDialog.showToast(response.summary);
        if (mounted) {
          Navigator.of(context).pop(response);
        }
      } else {
        final message = result.toString();
        SmartDialog.showToast(message.isEmpty ? '导入失败' : message);
      }
    } catch (error) {
      SmartDialog.showToast('导入失败: $error');
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  static String _formatDuration(int duration) {
    final minutes = duration ~/ 60;
    final seconds = (duration % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
