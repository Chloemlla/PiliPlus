class AppPermissionItem {
  const AppPermissionItem({
    required this.name,
    required this.purpose,
    this.scope,
  });

  final String name;
  final String purpose;

  /// Declared platform permission identifiers, shown as a reference.
  final String? scope;
}

/// Permissions declared by the app and the user-facing purpose of each.
/// Kept in sync with `android/app/src/main/AndroidManifest.xml`.
abstract final class AppPermissionsData {
  static const List<AppPermissionItem> items = [
    AppPermissionItem(
      name: '网络',
      purpose: '连接互联网，加载视频、图片、弹幕与接口数据。',
      scope: 'INTERNET / ACCESS_NETWORK_STATE / ACCESS_WIFI_STATE',
    ),
    AppPermissionItem(
      name: '相机',
      purpose: '扫码登录与扫码跳转（仅在主动发起扫码时请求）。',
      scope: 'CAMERA',
    ),
    AppPermissionItem(
      name: '照片与媒体',
      purpose: '选择图片作为头像或封面；播放本地音乐与视频。',
      scope: 'READ_MEDIA_IMAGES / READ_MEDIA_VIDEO / READ_MEDIA_AUDIO',
    ),
    AppPermissionItem(
      name: '存储',
      purpose: '读写下载文件与图片缓存（Android 12 及以下）。',
      scope: 'READ_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE',
    ),
    AppPermissionItem(
      name: '通知',
      purpose: '显示播放控制、下载完成与直播提醒等通知。',
      scope: 'POST_NOTIFICATIONS / POST_PROMOTED_NOTIFICATIONS',
    ),
    AppPermissionItem(
      name: '后台媒体播放',
      purpose: '切到后台或锁屏后继续播放音频/视频，并维持系统媒体通知。',
      scope: 'FOREGROUND_SERVICE / FOREGROUND_SERVICE_MEDIA_PLAYBACK / WAKE_LOCK',
    ),
  ];
}
