import 'package:pili_plus/services/audio_handler.dart';
import 'package:pili_plus/services/audio_session.dart';
import 'package:pili_plus/services/native_media_notification_service.dart';

VideoPlayerServiceHandler? videoPlayerServiceHandler;
AudioSessionHandler? audioSessionHandler;

Future<void> setupServiceLocator() async {
  nativeMediaNotificationService.ensureInitialized();
  final audio = await initAudioService();
  videoPlayerServiceHandler = audio;
  audioSessionHandler = AudioSessionHandler();
}
