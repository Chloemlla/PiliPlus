import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

abstract final class StorageUtils {
  static Future<void> saveBytes2File({
    required String name,
    required Uint8List bytes,
  }) async {
    try {
      final uri = await FilePicker.saveFile(fileName: name, bytes: bytes);
      if (uri == null) {
        SmartDialog.showToast("取消保存");
        return;
      }
      SmartDialog.showToast("已保存");
    } catch (e) {
      SmartDialog.showToast("保存失败: $e");
    }
  }
}
