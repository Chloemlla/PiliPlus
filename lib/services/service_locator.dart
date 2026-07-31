import 'package:get/get.dart';
import 'package:pili_plus/services/audio_handler.dart';
import 'package:pili_plus/services/audio_session.dart';
import 'package:pili_plus/services/download_manager_service.dart';
import 'package:pili_plus/services/native_media_notification_service.dart';

VideoPlayerServiceHandler? videoPlayerServiceHandler;
AudioSessionHandler? audioSessionHandler;
late DownloadManagerService downloadManagerService;

Future<void> setupServiceLocator() async {
  nativeMediaNotificationService.ensureInitialized();
  final audio = await initAudioService();
  videoPlayerServiceHandler = audio;
  audioSessionHandler = AudioSessionHandler();
  downloadManagerService = Get.put(DownloadManagerService());
}
