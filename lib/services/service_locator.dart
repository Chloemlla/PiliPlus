import 'package:get/get.dart';
import 'package:pili_plus/services/audio_handler.dart';
import 'package:pili_plus/services/audio_session.dart';
import 'package:pili_plus/services/danmaku_highlight_service.dart';
import 'package:pili_plus/services/download_manager_service.dart';
import 'package:pili_plus/services/live_update_service.dart';
import 'package:pili_plus/services/native_media_notification_service.dart';
import 'package:pili_plus/services/video_bookmark_service.dart';

VideoPlayerServiceHandler? videoPlayerServiceHandler;
AudioSessionHandler? audioSessionHandler;
late DownloadManagerService downloadManagerService;
late DanmakuHighlightService danmakuHighlightService;

Future<void> registerFeatureServices() async {
  await VideoBookmarkService.init();
  downloadManagerService = Get.isRegistered<DownloadManagerService>()
      ? Get.find<DownloadManagerService>()
      : Get.put(DownloadManagerService(), permanent: true);
  await downloadManagerService.initialize();
  danmakuHighlightService = Get.isRegistered<DanmakuHighlightService>()
      ? Get.find<DanmakuHighlightService>()
      : Get.put(DanmakuHighlightService(), permanent: true);
}

Future<void> setupServiceLocator() async {
  nativeMediaNotificationService.ensureInitialized();
  liveUpdateService.ensureInitialized();
  final audio = await initAudioService();
  videoPlayerServiceHandler = audio;
  audioSessionHandler = AudioSessionHandler();
}
