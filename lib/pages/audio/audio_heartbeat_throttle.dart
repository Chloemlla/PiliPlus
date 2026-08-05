import 'package:pili_plus/plugin/pl_player/models/heart_beat_type.dart';

final class AudioHeartbeatThrottle {
  int _lastProgress = 0;

  int get lastProgress => _lastProgress;

  bool shouldReport(
    int progress, {
    required HeartBeatType type,
    bool force = false,
  }) {
    final threshold = switch (type) {
      HeartBeatType.playing => 5,
      HeartBeatType.status => 2,
      HeartBeatType.completed => null,
    };
    if (threshold == null) return true;
    if (!force && progress - _lastProgress < threshold) return false;
    _lastProgress = progress;
    return true;
  }

  bool resetForBackwardSeek(int target) {
    if (target >= _lastProgress) return false;
    _lastProgress = target;
    return true;
  }

  void reset() {
    _lastProgress = 0;
  }
}
