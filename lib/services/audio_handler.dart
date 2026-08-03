import 'dart:async' show FutureOr;
import 'dart:io' show File, Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:pili_plus/common/constants.dart';
import 'package:pili_plus/grpc/bilibili/app/listener/v1.pb.dart'
    show DetailItem;
import 'package:pili_plus/models_new/download/bili_download_entry_info.dart';
import 'package:pili_plus/models_new/live/live_room_info_h5/data.dart';
import 'package:pili_plus/models_new/pgc/pgc_info_model/episode.dart';
import 'package:pili_plus/models_new/video/video_detail/data.dart';
import 'package:pili_plus/models_new/video/video_detail/page.dart';
import 'package:pili_plus/plugin/pl_player/controller.dart';
import 'package:pili_plus/plugin/pl_player/models/play_repeat.dart';
import 'package:pili_plus/plugin/pl_player/models/play_status.dart';
import 'package:pili_plus/services/native_media_notification_service.dart';
import 'package:pili_plus/services/shutdown_timer_service.dart';
import 'package:pili_plus/utils/android/bindings.g.dart';
import 'package:pili_plus/utils/image_utils.dart';
import 'package:pili_plus/utils/path_utils.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

Future<VideoPlayerServiceHandler> initAudioService() {
  // Android uses NativeMediaService for the MediaSession and notification.
  // Starting audio_service as a second service during cold start can leave
  // the activity without a focused window while Android is dispatching input.
  if (Platform.isAndroid) {
    return Future<VideoPlayerServiceHandler>.value(
      VideoPlayerServiceHandler(),
    );
  }

  return AudioService.init(
    builder: VideoPlayerServiceHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.chloemlla.piliplus.audio',
      androidNotificationChannelName: 'Audio Service ${Constants.appName}',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
      androidNotificationChannelDescription: 'Media notification channel',
      androidNotificationIcon: 'drawable/ic_notification_icon',
    ),
  );
}

class VideoPlayerServiceHandler extends BaseAudioHandler with SeekHandler {
  static final List<MediaItem> _item = [];

  /// Native position push throttling. SystemUI interpolates the scrubber
  /// while playing via speed + updateTime, so we push sparingly: push
  /// when paused (no interpolation), on a jump, or when the interval elapses.
  static bool shouldPushNativePosition({
    required bool playing,
    required Duration deltaFromPrevious,
    required Duration deltaFromLastPushed,
    required Duration? sinceLastPush,
    required Duration pushInterval,
    required Duration jumpThreshold,
  }) {
    final jumped =
        deltaFromPrevious.abs() >= jumpThreshold ||
        deltaFromLastPushed.abs() >= jumpThreshold;
    final due = sinceLastPush == null || sinceLastPush >= pushInterval;
    return !playing || jumped || due;
  }

  /// Whether a position tick after seek should be applied (true) or dropped
  /// as stale (false). Drops until the player reports a position near the
  /// seek target, or the grace window expires.
  static bool shouldAcceptPositionAfterSeek({
    required Duration position,
    required Duration seekTarget,
    required Duration settleThreshold,
    required bool graceExpired,
  }) {
    if (graceExpired) return true;
    return (position - seekTarget).abs() < settleThreshold;
  }

  // Player position stream is already ~1 Hz; push more slowly while playing so
  // SystemUI can interpolate via speed + updateTime and FGS rebuilds stay rare.
  static const Duration _nativePositionPushInterval = Duration(seconds: 3);
  static const Duration _nativePositionJumpThreshold = Duration(seconds: 2);
  bool enableBackgroundPlay = Pref.enableBackgroundPlay;

  MediaItem? _currentMediaItem;
  MediaItem? get currentMediaItem => _currentMediaItem;

  Duration _lastPosition = Duration.zero;
  Duration _lastPushedPosition = Duration.zero;
  Duration _lastBuffered = Duration.zero;
  DateTime? _lastNativePositionPush;

  /// After a seek, ignore stale player position ticks so the scrubber does not
  /// snap back before media_kit reports the new position.
  Duration? _pendingSeekPosition;
  DateTime? _pendingSeekUntil;
  PlayerStatus _lastStatus = PlayerStatus.paused;
  bool _lastBuffering = false;
  bool _lastIsLive = false;
  bool _lastVideoActions = false;
  double _lastPlaybackSpeed = 1.0;

  FutureOr<void>? Function()? onPlay;
  FutureOr<void>? Function()? onPause;
  FutureOr<void>? Function(Duration position)? onSeek;
  FutureOr<void>? Function()? onPrevious;
  FutureOr<void>? Function()? onNext;
  FutureOr<void>? Function()? onMiniPlayer;
  FutureOr<void>? Function()? onClearSession;
  FutureOr<void>? Function(double speed)? onSetSpeed;

  VideoPlayerServiceHandler() {
    if (Platform.isAndroid) {
      nativeMediaNotificationService
        ..ensureInitialized()
        ..onAction = _handleNativeAction;
    }
  }

  bool get _useNativeAndroidNotification => Platform.isAndroid;
  bool get _hasPlaybackTarget =>
      PlPlayerController.instanceExists() ||
      onPlay != null ||
      onPause != null ||
      onSeek != null;

  @override
  Future<void> play() async {
    await (onPlay?.call() ??
        PlPlayerController.playIfExists() ??
        Future.syncValue(null));
    // player.play();
  }

  @override
  Future<void> pause() async {
    await (onPause?.call() ?? PlPlayerController.pauseIfExists());
    // player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
    // Optimistic local position so notification scrubber / relative seeks stay
    // consistent until the player reports the new position.
    _noteOptimisticPosition(position);
    await (onSeek?.call(position) ??
        PlPlayerController.seekToIfExists(position, isSeek: false));
    // await player.seekTo(position);
  }

  Future<void> _handleNativeAction(
    String action,
    Map<String, dynamic> args,
  ) async {
    switch (action) {
      case 'play':
        await play();
      case 'pause':
        await pause();
      case 'seek':
        final positionMs = (args['positionMs'] as num?)?.toInt();
        if (positionMs != null) {
          await seek(Duration(milliseconds: positionMs));
        }
      case 'rewind':
        await _seekRelative(const Duration(seconds: -10));
      case 'fastForward':
        await _seekRelative(const Duration(seconds: 10));
      case 'previous':
        await onPrevious?.call();
      case 'next':
        await onNext?.call();
      case 'backgroundAudio':
        PlPlayerController.instance?.setOnlyPlayAudio();
        _syncNativePlaybackFlags();
      case 'miniPlayer':
        await onMiniPlayer?.call();
      case 'sleepTimer':
        shutdownTimerService.cycleQuickTimer();
      case 'speed':
        final nextSpeed = _nextPlaybackSpeed();
        if (onSetSpeed case final onSetSpeed?) {
          await onSetSpeed(nextSpeed);
        } else {
          await PlPlayerController.instance?.setPlaybackSpeed(nextSpeed);
        }
        _lastPlaybackSpeed = nextSpeed;
        _syncNativePlaybackFlags();
      case 'danmaku':
        if (PlPlayerController.instance case final player?) {
          player.showDanmaku = !player.showDanmaku;
          _syncNativePlaybackFlags();
        }
      case 'repeat':
        if (PlPlayerController.instance case final player?) {
          const values = PlayRepeat.values;
          final index = values.indexOf(player.playRepeat);
          player.setPlayRepeat(values[(index + 1) % values.length]);
          _syncNativePlaybackFlags();
        }
      case 'clearSession':
        if (onClearSession case final onClearSession?) {
          await onClearSession();
        } else {
          await pause();
        }
        clear();
    }
  }

  Future<void> _seekRelative(Duration offset) async {
    final duration = _currentMediaItem?.duration;
    var position = _lastPosition + offset;
    if (position < Duration.zero) {
      position = Duration.zero;
    }
    if (duration != null && duration > Duration.zero && position > duration) {
      position = duration;
    }
    // seek() already applies optimistic position + stale-tick guard.
    await seek(position);
    if (_useNativeAndroidNotification) {
      await nativeMediaNotificationService.updatePlayback({
        'positionMs': position.inMilliseconds,
        'bufferedMs': _lastBuffered.inMilliseconds,
        'durationMs': _currentMediaItem?.duration?.inMilliseconds,
        'playing': _lastStatus.isPlaying,
        'buffering': _lastBuffering,
        'completed': _lastStatus.isCompleted,
        'live': _lastIsLive,
      });
    }
  }

  void _noteOptimisticPosition(Duration position) {
    _lastPosition = position;
    _lastPushedPosition = position;
    _lastNativePositionPush = DateTime.now();
    _pendingSeekPosition = position;
    _pendingSeekUntil = DateTime.now().add(const Duration(seconds: 2));
  }

  double _nextPlaybackSpeed() {
    const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
    final current =
        PlPlayerController.instance?.playbackSpeed ?? _lastPlaybackSpeed;
    final index = speeds.indexWhere((e) => e > current + 0.01);
    return index == -1 ? speeds.first : speeds[index];
  }

  void setMediaItem(MediaItem newMediaItem) {
    _currentMediaItem = newMediaItem;
    if (!enableBackgroundPlay) return;
    // if (kDebugMode) {
    //   debugPrint("此时调用栈为：");
    //   debugPrint(newMediaItem);
    //   debugPrint(newMediaItem.title);
    //   debugPrint(StackTrace.current.toString());
    // }
    _lastPosition = Duration.zero;
    _lastPushedPosition = Duration.zero;
    _lastBuffered = Duration.zero;
    _lastNativePositionPush = null;
    _pendingSeekPosition = null;
    _pendingSeekUntil = null;
    _lastIsLive = newMediaItem.isLive ?? false;
    if (_useNativeAndroidNotification) {
      nativeMediaNotificationService.updateMetadata({
        'id': newMediaItem.id,
        'title': newMediaItem.title,
        'artist': newMediaItem.artist,
        'durationMs': newMediaItem.duration?.inMilliseconds,
        'artUri': newMediaItem.artUri?.toString(),
        'live': newMediaItem.isLive,
        'videoActions': _lastVideoActions,
        'supportsPrevious': onPrevious != null,
        'supportsNext': onNext != null,
        ..._nativePlaybackFlags(),
      });
      return;
    }
    if (!mediaItem.isClosed) mediaItem.add(newMediaItem);
  }

  /// Player-reported duration. Required for MediaStyle scrubber (duration > 0).
  void onDurationChange(Duration duration) {
    if (!enableBackgroundPlay || _item.isEmpty || !_hasPlaybackTarget) {
      return;
    }
    if (_lastIsLive || duration <= Duration.zero) return;

    final current = _currentMediaItem;
    if (current == null) return;
    if (current.duration == duration) return;

    final updated = current.copyWith(duration: duration);
    _currentMediaItem = updated;
    final index = _item.lastIndexWhere((item) => item.id == updated.id);
    if (index != -1) {
      _item[index] = updated;
    }

    if (_useNativeAndroidNotification) {
      nativeMediaNotificationService.updateMetadata({
        'durationMs': duration.inMilliseconds,
        'live': false,
        'positionMs': _lastPosition.inMilliseconds,
        'playing': _lastStatus.isPlaying,
        'buffering': _lastBuffering,
        'completed': _lastStatus.isCompleted,
        'supportsPrevious': onPrevious != null,
        'supportsNext': onNext != null,
        'videoActions': _lastVideoActions,
        ..._nativePlaybackFlags(),
      });
      return;
    }
    if (!mediaItem.isClosed) mediaItem.add(updated);
  }

  void onBufferedChange(Duration buffered) {
    if (!enableBackgroundPlay || _item.isEmpty || !_hasPlaybackTarget) {
      return;
    }
    if (_lastIsLive) return;
    // Store only; applied on the next playback/position push (no FGS spam).
    _lastBuffered = buffered;
  }

  void setPlaybackState(PlayerStatus status, bool isBuffering, bool isLive) {
    if (!enableBackgroundPlay || _item.isEmpty || !_hasPlaybackTarget) {
      return;
    }

    _lastStatus = status;
    _lastBuffering = isBuffering;
    _lastIsLive = isLive;
    if (_useNativeAndroidNotification) {
      nativeMediaNotificationService.updatePlayback({
        'playing': status.isPlaying,
        'buffering': isBuffering,
        'completed': status.isCompleted,
        'live': isLive,
        'positionMs': _lastPosition.inMilliseconds,
        'bufferedMs': _lastBuffered.inMilliseconds,
        'durationMs': _currentMediaItem?.duration?.inMilliseconds,
        'supportsPrevious': onPrevious != null,
        'supportsNext': onNext != null,
        'videoActions': _lastVideoActions,
        ..._nativePlaybackFlags(),
      });
      _lastPushedPosition = _lastPosition;
      _lastNativePositionPush = DateTime.now();
      if (Platform.isAndroid &&
          (AndroidHelper.isPipMode ||
              PlPlayerController.instance?.isAutoEnterPip == true)) {
        AndroidHelper.updatePipActions(
          PlatformDispatcher.instance.engineId!,
          isLive,
          status.isPlaying,
        );
      }
      return;
    }

    final AudioProcessingState processingState;
    if (status.isCompleted) {
      processingState = AudioProcessingState.completed;
    } else if (isBuffering) {
      processingState = AudioProcessingState.buffering;
    } else {
      processingState = AudioProcessingState.ready;
    }

    final playing = status.isPlaying;
    playbackState.add(
      playbackState.value.copyWith(
        processingState: isBuffering
            ? AudioProcessingState.buffering
            : processingState,
        controls: [
          if (!isLive)
            const MediaControl(
              androidIcon: 'drawable/ic_player_rewind_10s',
              label: 'Rewind',
              action: MediaAction.rewind,
            ),
          if (playing)
            const MediaControl(
              androidIcon: 'drawable/ic_player_pause',
              label: 'Pause',
              action: MediaAction.pause,
            )
          else
            const MediaControl(
              androidIcon: 'drawable/ic_player_play',
              label: 'Play',
              action: MediaAction.play,
            ),
          if (!isLive)
            const MediaControl(
              androidIcon: 'drawable/ic_player_fast_forward_10s',
              label: 'Fast Forward',
              action: MediaAction.fastForward,
            ),
        ],
        playing: playing,
        systemActions: const {MediaAction.seek},
      ),
    );
    if (Platform.isAndroid &&
        (AndroidHelper.isPipMode ||
            PlPlayerController.instance?.isAutoEnterPip == true)) {
      AndroidHelper.updatePipActions(
        PlatformDispatcher.instance.engineId!,
        isLive,
        playing,
      );
    }
  }

  Map<String, Object?> _nativePlaybackFlags() {
    final player = PlPlayerController.instance;
    return {
      'speed': player?.playbackSpeed ?? _lastPlaybackSpeed,
      'backgroundAudio': player?.onlyPlayAudio.value ?? false,
      'danmakuEnabled': player?.showDanmaku ?? true,
      'repeatMode': player?.playRepeat.label ?? '',
    };
  }

  void _syncNativePlaybackFlags() {
    if (!_useNativeAndroidNotification) return;
    nativeMediaNotificationService.updatePlayback({
      'playing': _lastStatus.isPlaying,
      'buffering': _lastBuffering,
      'completed': _lastStatus.isCompleted,
      'live': _lastIsLive,
      'positionMs': _lastPosition.inMilliseconds,
      'bufferedMs': _lastBuffered.inMilliseconds,
      'durationMs': _currentMediaItem?.duration?.inMilliseconds,
      'supportsPrevious': onPrevious != null,
      'supportsNext': onNext != null,
      'videoActions': _lastVideoActions,
      ..._nativePlaybackFlags(),
    });
    _lastPushedPosition = _lastPosition;
    _lastNativePositionPush = DateTime.now();
  }

  void onStatusChange(PlayerStatus status, bool isBuffering, isLive) {
    if (!enableBackgroundPlay) return;

    if (_item.isEmpty) return;
    setPlaybackState(status, isBuffering, isLive);
  }

  void onVideoDetailChange(
    dynamic data,
    int cid,
    String herotag, {
    String? artist,
    String? cover,
  }) {
    // if (kDebugMode) {
    //   debugPrint('当前调用栈为：');
    //   debugPrint(StackTrace.current);
    // }
    if (!_hasPlaybackTarget) return;
    if (data == null) return;

    Uri getUri(String? cover) => Uri.parse(ImageUtils.safeThumbnailUrl(cover));

    final previousExtras = _currentMediaItem?.extras;
    final previousBvid = previousExtras?['bvid'] as String?;
    final previousAuthorMid = (previousExtras?['authorMid'] as num?)?.toInt();
    Map<String, dynamic> watchMetadata({String? bvid, int? authorMid}) => {
      if (bvid != null && bvid.isNotEmpty) 'bvid': bvid,
      if (authorMid != null && authorMid > 0) 'authorMid': authorMid,
    };

    late final id = '$cid$herotag';
    final MediaItem mediaItem;
    var videoActions = false;
    switch (data) {
      case VideoDetailData(:final pages):
        videoActions = true;
        if (pages != null && pages.length > 1) {
          final current = pages.firstWhereOrNull((e) => e.cid == cid);
          mediaItem = MediaItem(
            id: id,
            title: current?.part ?? '',
            artist: data.owner?.name,
            duration: Duration(seconds: current?.duration ?? 0),
            artUri: getUri(data.pic),
            extras: watchMetadata(
              bvid: data.bvid,
              authorMid: data.owner?.mid,
            ),
          );
        } else {
          mediaItem = MediaItem(
            id: id,
            title: data.title ?? '',
            artist: data.owner?.name,
            duration: Duration(seconds: data.duration ?? 0),
            artUri: getUri(data.pic),
            extras: watchMetadata(
              bvid: data.bvid,
              authorMid: data.owner?.mid,
            ),
          );
        }
      case EpisodeItem():
        videoActions = true;
        mediaItem = MediaItem(
          id: id,
          title: data.showTitle ?? data.longTitle ?? data.title ?? '',
          artist: artist,
          duration: data.from == 'pugv'
              ? Duration(seconds: data.duration ?? 0)
              : Duration(milliseconds: data.duration ?? 0),
          artUri: getUri(data.cover),
          extras: watchMetadata(bvid: data.bvid),
        );
      case RoomInfoH5Data():
        mediaItem = MediaItem(
          id: id,
          title: data.roomInfo?.title ?? '',
          artist: data.anchorInfo?.baseInfo?.uname,
          artUri: getUri(data.roomInfo?.cover),
          isLive: true,
        );
      case Part():
        videoActions = true;
        mediaItem = MediaItem(
          id: id,
          title: data.part ?? '',
          artist: artist,
          duration: Duration(seconds: data.duration ?? 0),
          artUri: getUri(cover),
          extras: watchMetadata(
            bvid: previousBvid,
            authorMid: previousAuthorMid,
          ),
        );
      case DetailItem(:final arc):
        mediaItem = MediaItem(
          id: id,
          title: arc.title,
          artist: data.owner.name,
          duration: Duration(seconds: arc.duration.toInt()),
          artUri: getUri(arc.cover),
          extras: watchMetadata(authorMid: data.owner.mid.toInt()),
        );
      case BiliDownloadEntryInfo():
        videoActions = true;
        final coverFile = File(
          path.join(data.entryDirPath, PathUtils.coverName),
        );
        final uri = coverFile.existsSync()
            ? coverFile.absolute.uri
            : getUri(data.cover);
        mediaItem = MediaItem(
          id: id,
          title: data.showTitle,
          artist: data.ownerName,
          duration: Duration(milliseconds: data.totalTimeMilli),
          artUri: uri,
          extras: watchMetadata(
            bvid: data.bvid,
            authorMid: data.ownerId,
          ),
        );
      default:
        return;
    }
    // if (kDebugMode) debugPrint("exist: ${PlPlayerController.instanceExists()}");
    if (!_hasPlaybackTarget) return;
    if (enableBackgroundPlay) {
      _item.add(mediaItem);
    }
    _lastVideoActions = videoActions;
    setMediaItem(mediaItem);
  }

  void onVideoDetailDispose(String herotag) {
    if (!enableBackgroundPlay) {
      if (_currentMediaItem?.id.endsWith(herotag) ?? false) {
        _currentMediaItem = null;
      }
      return;
    }

    if (_item.isNotEmpty) {
      _item.removeWhere((item) => item.id.endsWith(herotag));
    }
    if (_useNativeAndroidNotification) {
      if (_item.isEmpty) {
        _currentMediaItem = null;
        nativeMediaNotificationService.stop();
      } else {
        setMediaItem(_item.last);
      }
      return;
    }
    if (_item.isNotEmpty) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ),
      );
      setMediaItem(_item.last);
      stop();
    }
  }

  void clear() {
    _currentMediaItem = null;
    if (!enableBackgroundPlay) return;
    if (_useNativeAndroidNotification) {
      _lastPosition = Duration.zero;
      _lastPushedPosition = Duration.zero;
      _lastBuffered = Duration.zero;
      _lastNativePositionPush = null;
      _pendingSeekPosition = null;
      _pendingSeekUntil = null;
      _lastStatus = PlayerStatus.paused;
      _item.clear();
      nativeMediaNotificationService.stop();
      return;
    }
    mediaItem.add(null);
    _item.clear();
    /**
     * if (playbackState.processingState == AudioProcessingState.idle &&
            previousState?.processingState != AudioProcessingState.idle) {
          await AudioService._stop();
        }
     */
    if (playbackState.value.processingState == AudioProcessingState.idle) {
      playbackState.add(
        PlaybackState(
          processingState: AudioProcessingState.completed,
          playing: false,
        ),
      );
    }
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle, playing: false),
    );
  }

  void clearControlCallbacks() {
    onPrevious = null;
    onNext = null;
    onMiniPlayer = null;
    onClearSession = null;
    onSetSpeed = null;
  }

  void onPositionChange(Duration position) {
    if (!enableBackgroundPlay || _item.isEmpty || !_hasPlaybackTarget) {
      return;
    }

    // Drop stale ticks after seek so the scrubber does not jump backward.
    if (_pendingSeekPosition != null) {
      final target = _pendingSeekPosition!;
      final expired =
          _pendingSeekUntil == null ||
          DateTime.now().isAfter(_pendingSeekUntil!);
      if (!shouldAcceptPositionAfterSeek(
        position: position,
        seekTarget: target,
        settleThreshold: _nativePositionJumpThreshold,
        graceExpired: expired,
      )) {
        return;
      }
      _pendingSeekPosition = null;
      _pendingSeekUntil = null;
    }

    final previous = _lastPosition;
    _lastPosition = position;
    if (_useNativeAndroidNotification) {
      final now = DateTime.now();
      final sinceLastPush = _lastNativePositionPush == null
          ? null
          : now.difference(_lastNativePositionPush!);
      if (!shouldPushNativePosition(
        playing: _lastStatus.isPlaying,
        deltaFromPrevious: position - previous,
        deltaFromLastPushed: position - _lastPushedPosition,
        sinceLastPush: sinceLastPush,
        pushInterval: _nativePositionPushInterval,
        jumpThreshold: _nativePositionJumpThreshold,
      )) {
        return;
      }

      _lastNativePositionPush = now;
      _lastPushedPosition = position;
      nativeMediaNotificationService.updatePlayback({
        'positionMs': position.inMilliseconds,
        'bufferedMs': _lastBuffered.inMilliseconds,
        'playing': _lastStatus.isPlaying,
        'buffering': _lastBuffering,
        'completed': _lastStatus.isCompleted,
        'live': _lastIsLive,
        'durationMs': _currentMediaItem?.duration?.inMilliseconds,
        'supportsPrevious': onPrevious != null,
        'supportsNext': onNext != null,
        'videoActions': _lastVideoActions,
        ..._nativePlaybackFlags(),
      });
      return;
    }

    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }
}
