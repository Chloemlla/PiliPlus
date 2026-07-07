import 'dart:io' show Platform;

import 'package:flutter/services.dart';

abstract final class AndroidCredentialAuth {
  static const _channel = MethodChannel('pili_plus/android_credential_auth');

  static Future<bool> confirm({
    required String title,
    required String description,
  }) {
    if (!Platform.isAndroid) return Future.value(false);
    return _channel.invokeMethod<bool>(
          'confirmDeviceCredential',
          {
            'title': title,
            'description': description,
          },
        ).then((value) => value ?? false);
  }
}
