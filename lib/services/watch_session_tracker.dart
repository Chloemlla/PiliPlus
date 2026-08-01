import 'dart:math' show max;

final class WatchSessionMetadata {
  const WatchSessionMetadata({
    required this.bvid,
    required this.title,
    required this.authorName,
    required this.authorMid,
  });

  final String bvid;
  final String title;
  final String authorName;
  final int authorMid;
}

final class PendingWatchSession {
  const PendingWatchSession({
    required this.metadata,
    required this.watchedMilliseconds,
    required this.endedAt,
  });

  final WatchSessionMetadata metadata;
  final int watchedMilliseconds;
  final DateTime endedAt;

  int get watchedSeconds =>
      watchedMilliseconds ~/ Duration.millisecondsPerSecond;
}

/// Counts actual media-position advances rather than wall-clock time.
/// Pauses, buffering, seeks and position events after five minutes of silence
/// only reset the baseline and never increase watched time.
final class WatchSessionTracker {
  WatchSessionTracker({
    this.inactivityTimeout = const Duration(minutes: 5),
    this.persistenceChunk = const Duration(seconds: 30),
  });

  final Duration inactivityTimeout;
  final Duration persistenceChunk;

  WatchSessionMetadata? _metadata;
  Duration? _lastPosition;
  DateTime? _lastEventAt;
  int _watchedMilliseconds = 0;

  void begin({
    required WatchSessionMetadata metadata,
    required Duration position,
    required DateTime at,
  }) {
    _metadata = metadata;
    _lastPosition = position;
    _lastEventAt = at;
    _watchedMilliseconds = 0;
  }

  void updateMetadata(WatchSessionMetadata metadata) {
    if (_metadata?.bvid == metadata.bvid) {
      _metadata = metadata;
    }
  }

  List<PendingWatchSession> markSeek({
    required Duration position,
    required DateTime at,
  }) {
    _lastPosition = position;
    _lastEventAt = at;
    return const [];
  }

  List<PendingWatchSession> onPosition({
    required Duration position,
    required DateTime at,
    required bool isPlaying,
    required bool isBuffering,
    required bool isSeeking,
    required double playbackSpeed,
  }) {
    final metadata = _metadata;
    final lastPosition = _lastPosition;
    final lastEventAt = _lastEventAt;
    if (metadata == null || lastPosition == null || lastEventAt == null) {
      _lastPosition = position;
      _lastEventAt = at;
      return const [];
    }

    final completed = <PendingWatchSession>[];
    final elapsed = at.difference(lastEventAt);
    if (elapsed >= inactivityTimeout || !_isSameLocalDay(lastEventAt, at)) {
      final pending = _takePending(lastEventAt);
      if (pending != null) completed.add(pending);
      _watchedMilliseconds = 0;
      _lastPosition = position;
      _lastEventAt = at;
      return completed;
    }

    final positionDelta = position - lastPosition;
    final speed = max(playbackSpeed, 1.0);
    final plausibleAdvance = Duration(
      milliseconds: max(
        const Duration(seconds: 5).inMilliseconds,
        (elapsed.inMilliseconds * speed * 2).round() +
            const Duration(seconds: 2).inMilliseconds,
      ),
    );
    final shouldCount =
        isPlaying &&
        !isBuffering &&
        !isSeeking &&
        positionDelta > Duration.zero &&
        positionDelta <= plausibleAdvance;
    if (shouldCount) {
      _watchedMilliseconds += positionDelta.inMilliseconds;
    }

    _lastPosition = position;
    _lastEventAt = at;
    if (_watchedMilliseconds >= persistenceChunk.inMilliseconds) {
      final pending = _takePending(at);
      if (pending != null) completed.add(pending);
    }
    return completed;
  }

  List<PendingWatchSession> finish(DateTime at) {
    final pending = _takePending(at);
    _metadata = null;
    _lastPosition = null;
    _lastEventAt = null;
    return pending == null ? const [] : [pending];
  }

  List<PendingWatchSession> flush(DateTime at) {
    final pending = _takePending(at);
    return pending == null ? const [] : [pending];
  }

  PendingWatchSession? _takePending(DateTime endedAt) {
    final metadata = _metadata;
    final completeMilliseconds =
        (_watchedMilliseconds ~/ Duration.millisecondsPerSecond) *
        Duration.millisecondsPerSecond;
    if (metadata == null || completeMilliseconds <= 0) return null;

    _watchedMilliseconds -= completeMilliseconds;
    return PendingWatchSession(
      metadata: metadata,
      watchedMilliseconds: completeMilliseconds,
      endedAt: endedAt,
    );
  }

  static bool _isSameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
