import 'package:pili_plus/pages/audio/audio_heartbeat_throttle.dart';
import 'package:pili_plus/plugin/pl_player/models/heart_beat_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backward seek reports immediately and resumes normal heartbeat', () {
    final throttle = AudioHeartbeatThrottle();

    expect(
      throttle.shouldReport(
        1200,
        type: HeartBeatType.playing,
        force: true,
      ),
      isTrue,
    );
    expect(throttle.resetForBackwardSeek(300), isTrue);
    expect(throttle.lastProgress, 300);
    expect(
      throttle.shouldReport(
        300,
        type: HeartBeatType.status,
        force: true,
      ),
      isTrue,
    );
    expect(
      throttle.shouldReport(304, type: HeartBeatType.playing),
      isFalse,
    );
    expect(
      throttle.shouldReport(305, type: HeartBeatType.playing),
      isTrue,
    );
  });
}
