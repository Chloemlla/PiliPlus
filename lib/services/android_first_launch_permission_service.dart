import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pili_plus/utils/device_utils.dart';
import 'package:pili_plus/utils/permission_handler.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';

class AndroidFirstLaunchPermissionGate extends StatefulWidget {
  const AndroidFirstLaunchPermissionGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<AndroidFirstLaunchPermissionGate> createState() =>
      _AndroidFirstLaunchPermissionGateState();
}

class _AndroidFirstLaunchPermissionGateState
    extends State<AndroidFirstLaunchPermissionGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AndroidFirstLaunchPermissionService.requestMissingPermissions(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

abstract final class AndroidFirstLaunchPermissionService {
  static bool _isRunning = false;

  static Future<void> requestMissingPermissions(BuildContext context) async {
    if (!Platform.isAndroid || _isRunning) {
      return;
    }

    final hasRequested = GStorage.setting.get(
      SettingBoxKey.androidFirstLaunchPermissionsRequested,
      defaultValue: false,
    );
    if (hasRequested) {
      return;
    }

    _isRunning = true;
    var completed = false;
    try {
      for (final item in _permissionItems()) {
        if (!context.mounted) {
          return;
        }
        final isMissing = await item.isMissing();
        if (!context.mounted) {
          return;
        }
        if (!isMissing) {
          continue;
        }

        final shouldRequest = await _showReasonDialog(context, item);
        if (!context.mounted) {
          return;
        }
        if (!shouldRequest) {
          continue;
        }

        final status = await item.request();
        if (!context.mounted) {
          return;
        }
        if (item.continueContent != null) {
          await _showContinueDialog(
            context,
            title: item.title,
            content: item.continueContent!,
          );
          if (!context.mounted) {
            return;
          }
        }
        if (status == PermissionStatus.permanentlyDenied) {
          await _showOpenAppSettingsDialog(context, item.title);
        }
      }

      completed = true;
    } finally {
      _isRunning = false;
      if (completed) {
        await GStorage.setting.put(
          SettingBoxKey.androidFirstLaunchPermissionsRequested,
          true,
        );
      }
    }
  }

  static List<_PermissionItem> _permissionItems() {
    final sdkInt = DeviceUtils.sdkInt;
    return [
      if (sdkInt >= 33)
        _PermissionItem.runtime(
          permission: Permission.notification,
          title: '通知权限',
          reason: '用于显示下载进度、播放控制和后台音频通知，避免任务在后台运行时缺少状态提示。',
        ),
      if (sdkInt >= 33)
        _PermissionItem.runtime(
          permission: Permission.photos,
          title: '图片权限',
          reason: '用于读取和保存图片、头像、动态配图以及相册中的相关媒体内容。',
        ),
      if (sdkInt >= 33)
        _PermissionItem.runtime(
          permission: Permission.videos,
          title: '视频权限',
          reason: '用于读取和管理本地视频媒体，支持离线视频、视频保存和分享相关功能。',
        ),
      if (sdkInt >= 33)
        _PermissionItem.runtime(
          permission: Permission.audio,
          title: '音频权限',
          reason: '用于读取本地音频媒体，保证音频播放、后台播放和媒体通知功能正常工作。',
        ),
      if (sdkInt < 33)
        _PermissionItem.runtime(
          permission: Permission.storage,
          title: '存储权限',
          reason: '用于在 Android 12 及以下读取和保存图片、离线视频、缓存文件以及导入导出内容。',
        ),
      if (sdkInt >= 23)
        _PermissionItem(
          title: '系统亮度权限',
          reason: '用于在播放器里直接调节系统亮度。若只使用应用内亮度调节，可以暂不授权。',
          requestLabel: '去授权',
          isMissing: () async => !await _canChangeSystemBrightness(),
          request: _requestSystemBrightnessPermission,
          continueContent: '请在系统设置中允许修改系统设置。完成后返回 PiliPlus，并点击继续处理后续权限。',
        ),
    ];
  }

  static Future<bool> _canChangeSystemBrightness() async {
    try {
      return await ScreenBrightnessPlatform.instance.canChangeSystemBrightness;
    } catch (_) {
      return true;
    }
  }

  static Future<PermissionStatus?> _requestSystemBrightnessPermission() async {
    var brightness = 0.5;
    try {
      brightness = await ScreenBrightnessPlatform.instance.system;
    } catch (_) {}

    try {
      await ScreenBrightnessPlatform.instance.setSystemScreenBrightness(
        brightness.clamp(0.0, 1.0).toDouble(),
      );
    } catch (_) {}

    return null;
  }

  static Future<bool> _showReasonDialog(
    BuildContext context,
    _PermissionItem item,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(item.title),
            content: Text(item.reason),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('暂不授权'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(item.requestLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<void> _showOpenAppSettingsDialog(
    BuildContext context,
    String title,
  ) async {
    final openSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: const Text('该权限已被系统标记为不再询问，需要前往应用设置中手动开启。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('跳过'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('打开设置'),
              ),
            ],
          ),
        ) ??
        false;

    if (openSettings) {
      await openAppSettings();
      if (context.mounted) {
        await _showContinueDialog(
          context,
          title: title,
          content: '完成授权后返回 PiliPlus，并点击继续处理后续权限。',
        );
      }
    }
  }

  static Future<void> _showContinueDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }
}

class _PermissionItem {
  const _PermissionItem({
    required this.title,
    required this.reason,
    required this.isMissing,
    required this.request,
    this.requestLabel = '继续授权',
    this.continueContent,
  });

  factory _PermissionItem.runtime({
    required Permission permission,
    required String title,
    required String reason,
  }) {
    return _PermissionItem(
      title: title,
      reason: reason,
      isMissing: () => _isRuntimePermissionMissing(permission),
      request: permission.request,
    );
  }

  final String title;
  final String reason;
  final String requestLabel;
  final String? continueContent;
  final Future<bool> Function() isMissing;
  final Future<PermissionStatus?> Function() request;

  static Future<bool> _isRuntimePermissionMissing(
    Permission permission,
  ) async {
    final status = await permission.status;
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.limited ||
      PermissionStatus.provisional => false,
      _ => true,
    };
  }
}
