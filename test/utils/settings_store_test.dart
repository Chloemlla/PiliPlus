import 'dart:io';

import 'package:pili_plus/plugin/pl_player/models/play_repeat.dart';
import 'package:pili_plus/utils/storage/settings_store.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory hiveDirectory;
  late Box<dynamic> setting;
  late Box<dynamic> video;
  late SettingsStore store;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp(
      'pili_settings_store_test_',
    );
    Hive.init(hiveDirectory.path);
  });

  setUp(() async {
    setting = await Hive.openBox<dynamic>('setting');
    video = await Hive.openBox<dynamic>('video');
    store = SettingsStore(setting, video);
  });

  tearDown(() async {
    await setting.close();
    await video.close();
    await Hive.deleteBoxFromDisk('setting');
    await Hive.deleteBoxFromDisk('video');
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('persists typed window and playback settings', () async {
    await store.setWindowMaximized(true);
    await store.setWindowBounds(
      width: 1180,
      height: 720,
      left: 20,
      top: 30,
    );
    await store.setDesktopVolume(2.5);
    await store.setMaxVolume(2);
    await store.setAudioPlayMode(PlayRepeat.listCycle);
    await store.setVideoPlayRepeat(PlayRepeat.singleCycle);

    expect(setting.get(SettingBoxKey.isWindowMaximized), isTrue);
    expect(setting.get(SettingBoxKey.windowSize), <double>[1180, 720]);
    expect(setting.get(SettingBoxKey.windowPosition), <double>[20, 30]);
    expect(setting.get(SettingBoxKey.desktopVolume), 2);
    expect(setting.get(SettingBoxKey.maxVolume), 2);
    expect(
      setting.get(SettingBoxKey.audioPlayMode),
      PlayRepeat.listCycle.index,
    );
    expect(video.get(VideoBoxKey.playRepeat), PlayRepeat.singleCycle.index);
  });

  test('rejects invalid values before mutating storage', () {
    expect(
      () => store.setWindowBounds(
        width: double.nan,
        height: 720,
        left: 0,
        top: 0,
      ),
      throwsArgumentError,
    );
    expect(() => store.setDesktopVolume(3.1), throwsArgumentError);
    expect(() => store.setMaxVolume(0.9), throwsArgumentError);

    expect(setting.isEmpty, isTrue);
    expect(video.isEmpty, isTrue);
  });
}
