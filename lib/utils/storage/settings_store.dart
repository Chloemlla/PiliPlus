import 'package:pili_plus/plugin/pl_player/models/play_repeat.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:hive_ce/hive.dart';

final class SettingsStore {
  const SettingsStore(Box<dynamic> setting, Box<dynamic> video)
    : _setting = setting,
      _video = video;

  final Box<dynamic> _setting;
  final Box<dynamic> _video;

  Future<void> setWindowMaximized(bool value) =>
      _setting.put(SettingBoxKey.isWindowMaximized, value);

  Future<void> setWindowPosition({
    required double left,
    required double top,
  }) {
    _requireFinite(left, 'left');
    _requireFinite(top, 'top');
    return _setting.put(SettingBoxKey.windowPosition, <double>[left, top]);
  }

  Future<void> setWindowBounds({
    required double width,
    required double height,
    required double left,
    required double top,
  }) {
    _requirePositiveFinite(width, 'width');
    _requirePositiveFinite(height, 'height');
    _requireFinite(left, 'left');
    _requireFinite(top, 'top');
    return _setting.putAll(<String, Object>{
      SettingBoxKey.windowSize: <double>[width, height],
      SettingBoxKey.windowPosition: <double>[left, top],
    });
  }

  Future<void> setDesktopVolume(double value) {
    if (!value.isFinite || value < 0 || value > 3) {
      throw ArgumentError.value(value, 'value', 'must be between 0 and 3');
    }
    return _setting.put(SettingBoxKey.desktopVolume, value);
  }

  Future<void> setMaxVolume(double value) {
    if (!value.isFinite || value < 1 || value > 3) {
      throw ArgumentError.value(value, 'value', 'must be between 1 and 3');
    }
    final desktopVolume = _setting.get(SettingBoxKey.desktopVolume);
    return _setting.putAll(<String, Object>{
      SettingBoxKey.maxVolume: value,
      if (desktopVolume is num && desktopVolume > value)
        SettingBoxKey.desktopVolume: value,
    });
  }

  Future<void> setAudioPlayMode(PlayRepeat value) =>
      _setting.put(SettingBoxKey.audioPlayMode, value.index);

  Future<void> setVideoPlayRepeat(PlayRepeat value) =>
      _video.put(VideoBoxKey.playRepeat, value.index);

  static void _requireFinite(double value, String name) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, name, 'must be finite');
    }
  }

  static void _requirePositiveFinite(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name, 'must be positive and finite');
    }
  }
}
