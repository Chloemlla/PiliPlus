import 'dart:io';

import 'package:pili_plus/utils/permission_handler.dart';
import 'package:flutter/services.dart';

abstract final class AndroidQrScanner {
  static const _channel = MethodChannel('pili_plus/android_qr_scanner');

  static bool get isSupported => Platform.isAndroid;

  static Future<String?> scanCamera() async {
    if (!isSupported) {
      throw const AndroidQrScannerException(
        'unsupported',
        '当前平台不支持摄像头扫码',
      );
    }
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      throw AndroidQrScannerException(
        status.isPermanentlyDenied
            ? 'permission_permanently_denied'
            : 'permission_denied',
        status.isPermanentlyDenied ? '相机权限已被永久拒绝，请在系统设置中允许' : '需要相机权限才能扫描二维码',
      );
    }
    return _invoke('scanCamera');
  }

  static Future<String?> scanImage() {
    if (!isSupported) {
      throw const AndroidQrScannerException(
        'unsupported',
        '当前平台不支持从相册识别二维码',
      );
    }
    return _invoke('scanImage');
  }

  static Future<String?> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<String>(method);
    } on PlatformException catch (error) {
      throw AndroidQrScannerException(
        error.code,
        error.message ?? '二维码识别失败',
      );
    }
  }
}

final class AndroidQrScannerException implements Exception {
  const AndroidQrScannerException(this.code, this.message);

  final String code;
  final String message;

  bool get canOpenSettings => code == 'permission_permanently_denied';

  @override
  String toString() => message;
}
