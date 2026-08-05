import 'package:flutter/material.dart';
import 'package:pili_plus/models/video_bookmark.dart';

Future<({String name, String? note})?> showVideoBookmarkEditorDialog({
  required BuildContext context,
  required String title,
  required int timestampSeconds,
  required String defaultName,
  String initialName = '',
  String? initialNote,
}) async {
  final nameController = TextEditingController(text: initialName);
  final noteController = TextEditingController(text: initialNote ?? '');

  try {
    return await showDialog<({String name, String? note})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '时间：${VideoBookmark.formatTimestamp(timestampSeconds)}',
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                maxLength: VideoBookmark.maxNameLength,
                decoration: InputDecoration(
                  labelText: '标记名称',
                  hintText: defaultName,
                  border: const OutlineInputBorder(),
                ),
                autofocus: initialName.isEmpty,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLength: VideoBookmark.maxNoteLength,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final note = noteController.text.trim();
              Navigator.pop(
                dialogContext,
                (
                  name: name.isEmpty ? defaultName : name,
                  note: note.isEmpty ? null : note,
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  } finally {
    nameController.dispose();
    noteController.dispose();
  }
}
