import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';

abstract interface class PipStateStore {
  Object? read(String key);

  Future<void> write(String key, Object? value);

  Future<void> delete(String key);
}

final class PipPlaybackState {
  const PipPlaybackState({
    required this.bvid,
    required this.cid,
    required this.positionMs,
    required this.savedAtMs,
    this.title,
    this.cover,
  });

  final String bvid;
  final int cid;
  final int positionMs;
  final int savedAtMs;
  final String? title;
  final String? cover;

  Map<String, Object?> toJson() => {
    'version': 2,
    'bvid': bvid,
    'cid': cid,
    'positionMs': positionMs,
    'savedAtMs': savedAtMs,
    'title': title,
    'cover': cover,
  };

  static PipPlaybackState? fromJson(Object? value) {
    if (value is! Map) return null;
    if (value['version'] != 2) return null;
    final bvid = value['bvid'];
    final cid = value['cid'];
    final positionMs = value['positionMs'];
    final savedAtMs = value['savedAtMs'];
    if (bvid is! String ||
        bvid.trim().isEmpty ||
        cid is! num ||
        cid.toInt() <= 0 ||
        savedAtMs is! num ||
        savedAtMs.toInt() <= 0) {
      return null;
    }
    return PipPlaybackState(
      bvid: bvid,
      cid: cid.toInt(),
      positionMs: positionMs is num
          ? positionMs.toInt().clamp(0, 1 << 53).toInt()
          : 0,
      savedAtMs: savedAtMs.toInt(),
      title: value['title'] is String ? value['title'] as String : null,
      cover: value['cover'] is String ? value['cover'] as String : null,
    );
  }
}

/// Stores one coherent PiP playback snapshot and owns its native mode callback.
/// A matching player can restore the position after activity recreation; the
/// snapshot is cleared when PiP exits, playback completes, or the player closes.
class PipPersistentService {
  PipPersistentService({
    required this._store,
    DateTime Function()? clock,
    this.maxRestoreAge = const Duration(hours: 12),
  }) : _clock = clock ?? DateTime.now;

  static final PipPersistentService instance = PipPersistentService(
    store: _LocalCachePipStateStore(),
  );

  static const String _stateKey = 'pipPlaybackStateV2';
  static const MethodChannel _channel = MethodChannel('pili_plus/pip');
  static const List<String> _legacyKeys = [
    LocalCacheKey.pipVideoBvid,
    LocalCacheKey.pipVideoCid,
    LocalCacheKey.pipVideoPosition,
    LocalCacheKey.pipVideoTitle,
    LocalCacheKey.pipVideoCover,
  ];

  final PipStateStore _store;
  final DateTime Function() _clock;
  final Duration maxRestoreAge;

  PipPlaybackState? _cachedState;
  bool _cacheLoaded = false;
  bool _platformCallbacksInstalled = false;
  Future<void> _operationTail = Future<void>.value();

  /// Callback invoked when Android PiP mode changes.
  /// [isInPipMode] is true when entering PiP, false when exiting.
  void Function(bool isInPipMode)? onPipModeChanged;

  void ensurePlatformCallbacks() {
    if (_platformCallbacksInstalled || !Platform.isAndroid) return;
    _platformCallbacksInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'modeChanged') return;
      final isInPipMode = call.arguments as bool? ?? false;
      onPipModeChanged?.call(isInPipMode);
      if (!isInPipMode) {
        await clearPipState();
      }
    });
  }

  Future<void> savePipState({
    required String bvid,
    required int cid,
    required int positionMs,
    String? title,
    String? cover,
  }) async {
    if (bvid.isEmpty || cid <= 0) return;
    final state = PipPlaybackState(
      bvid: bvid,
      cid: cid,
      positionMs: positionMs < 0 ? 0 : positionMs,
      savedAtMs: _clock().millisecondsSinceEpoch,
      title: title,
      cover: cover,
    );
    _cachedState = state;
    _cacheLoaded = true;
    await _enqueue(() => _store.write(_stateKey, state.toJson()));
  }

  PipPlaybackState? get state {
    if (!_cacheLoaded) {
      _cachedState =
          PipPlaybackState.fromJson(_store.read(_stateKey)) ??
          _readLegacyState();
      _cacheLoaded = true;
    }
    final current = _cachedState;
    if (current == null) return null;
    final age = _clock().difference(
      DateTime.fromMillisecondsSinceEpoch(current.savedAtMs),
    );
    if (age.isNegative || age > maxRestoreAge) {
      _cachedState = null;
      return null;
    }
    return current;
  }

  bool get hasPipState => state != null;

  Duration? restorePositionFor({required String bvid, required int cid}) {
    final current = state;
    if (current == null || current.bvid != bvid || current.cid != cid) {
      return null;
    }
    return Duration(milliseconds: current.positionMs);
  }

  Future<void> clearIfMatches({required String bvid, required int cid}) async {
    final current = state;
    if (current == null || current.bvid != bvid || current.cid != cid) return;
    await clearPipState();
  }

  Future<void> clearPipState() async {
    _cachedState = null;
    _cacheLoaded = true;
    await _enqueue(
      () => Future.wait([
        _store.delete(_stateKey),
        for (final key in _legacyKeys) _store.delete(key),
      ]),
    );
  }

  PipPlaybackState? _readLegacyState() {
    final bvid = _store.read(LocalCacheKey.pipVideoBvid);
    final cid = _store.read(LocalCacheKey.pipVideoCid);
    if (bvid is! String ||
        bvid.trim().isEmpty ||
        cid is! num ||
        cid.toInt() <= 0) {
      return null;
    }
    final position = _store.read(LocalCacheKey.pipVideoPosition);
    return PipPlaybackState(
      bvid: bvid,
      cid: cid.toInt(),
      positionMs: position is num
          ? position.toInt().clamp(0, 1 << 53).toInt()
          : 0,
      savedAtMs: _clock().millisecondsSinceEpoch,
      title: _readString(LocalCacheKey.pipVideoTitle),
      cover: _readString(LocalCacheKey.pipVideoCover),
    );
  }

  String? _readString(String key) {
    final value = _store.read(key);
    return value is String ? value : null;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = Completer<void>();
    final previous = _operationTail;
    _operationTail = () async {
      try {
        await previous;
      } catch (_) {
        // A failed persistence attempt must not poison later cleanup writes.
      }
      try {
        await operation();
        result.complete();
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    }();
    return result.future;
  }
}

final class _LocalCachePipStateStore implements PipStateStore {
  @override
  Object? read(String key) => GStorage.localCache.get(key);

  @override
  Future<void> write(String key, Object? value) =>
      GStorage.localCache.put(key, value);

  @override
  Future<void> delete(String key) => GStorage.localCache.delete(key);
}
