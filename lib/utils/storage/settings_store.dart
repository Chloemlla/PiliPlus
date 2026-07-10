import 'package:hive_ce/hive.dart';

final class SettingsStore {
  const SettingsStore(this.setting, this.video);

  final Box<dynamic> setting;
  final Box<dynamic> video;

  Future<void> putSetting(String key, Object? value) => setting.put(key, value);

  Future<void> putSettings(Map<dynamic, dynamic> values) =>
      setting.putAll(values);

  Future<void> putVideo(String key, Object? value) => video.put(key, value);
}
