import 'dart:async';

import 'package:pili_plus/models/quality_mode.dart';
import 'package:pili_plus/services/quality_network_speed_probe.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

typedef NetworkTypeReader = Future<NetworkType> Function();
typedef BatteryLevelReader = Future<int> Function();
typedef BatteryStateReader = Future<BatteryState> Function();
typedef QualityClock = DateTime Function();

/// Computes a supported video quality from live network and battery inputs.
class QualityRecommendationService {
  QualityRecommendationService({
    NetworkTypeReader? networkTypeReader,
    Stream<NetworkType>? networkTypeChanges,
    BatteryLevelReader? batteryLevelReader,
    BatteryStateReader? batteryStateReader,
    NetworkSpeedProbe? speedProbe,
    QualityClock? clock,
  }) {
    final connectivity = Connectivity();
    final battery = Battery();
    _networkTypeReader =
        networkTypeReader ??
        () => connectivity.checkConnectivity().then(_mapConnectivity);
    _networkTypeChanges =
        networkTypeChanges ??
        connectivity.onConnectivityChanged.map(_mapConnectivity);
    _batteryLevelReader = batteryLevelReader ?? () => battery.batteryLevel;
    _batteryStateReader = batteryStateReader ?? () => battery.batteryState;
    _speedProbe = speedProbe ?? BiliCdnNetworkSpeedProbe();
    _clock = clock ?? DateTime.now;
  }

  static final QualityRecommendationService instance =
      QualityRecommendationService();

  late final NetworkTypeReader _networkTypeReader;
  late final Stream<NetworkType> _networkTypeChanges;
  late final BatteryLevelReader _batteryLevelReader;
  late final BatteryStateReader _batteryStateReader;
  late final NetworkSpeedProbe _speedProbe;
  late final QualityClock _clock;

  static const Duration speedCacheDuration = Duration(minutes: 5);
  static const Duration speedProbeDuration = Duration(seconds: 3);

  Future<void>? _initialization;
  StreamSubscription<NetworkType>? _networkSubscription;
  NetworkType _lastNetworkType = NetworkType.none;
  _SpeedCache? _speedCache;

  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      _lastNetworkType = await _networkTypeReader();
    } catch (_) {
      _lastNetworkType = NetworkType.none;
    }
    _networkSubscription ??= _networkTypeChanges.listen(
      _onNetworkTypeChanged,
      onError: (_) {},
    );
  }

  void _onNetworkTypeChanged(NetworkType networkType) {
    if (networkType != _lastNetworkType) {
      _lastNetworkType = networkType;
      clearSpeedCache();
    }
  }

  static NetworkType _mapConnectivity(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return NetworkType.wifi;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      // connectivity_plus does not expose the cellular radio generation.
      return NetworkType.cellular4g;
    }
    if (results.any((result) => result != ConnectivityResult.none)) {
      // VPN, Bluetooth and platform-specific transports retain a conservative
      // connected heuristic when their underlying transport is unavailable.
      return NetworkType.cellular4g;
    }
    return NetworkType.none;
  }

  /// Measures the current CDN throughput and reuses it for five minutes.
  Future<double?> measureNetworkSpeed(Uri? probeUri) async {
    await init();
    final cache = _speedCache;
    if (cache != null && cache.networkType == _lastNetworkType) {
      final age = _clock().difference(cache.measuredAt);
      if (!age.isNegative && age < speedCacheDuration) {
        return cache.mbps;
      }
    }
    if (probeUri == null || _lastNetworkType == NetworkType.none) return null;

    final probeNetworkType = _lastNetworkType;
    final measured = await _speedProbe.measure(
      probeUri,
      maxDuration: speedProbeDuration,
    );
    if (probeNetworkType != _lastNetworkType ||
        measured == null ||
        !measured.isFinite ||
        measured <= 0) {
      return null;
    }

    _speedCache = _SpeedCache(
      mbps: measured,
      measuredAt: _clock(),
      networkType: probeNetworkType,
    );
    return measured;
  }

  Future<int> getBatteryLevel() async {
    try {
      return (await _batteryLevelReader()).clamp(0, 100).toInt();
    } catch (_) {
      // A missing platform implementation must not force a low-quality mode.
      return 100;
    }
  }

  Future<BatteryState> getBatteryState() async {
    try {
      return await _batteryStateReader();
    } catch (_) {
      return BatteryState.unknown;
    }
  }

  Future<bool> isLowBattery() =>
      getBatteryLevel().then((batteryLevel) => batteryLevel < 20);

  Future<bool> isCharging() async {
    final state = await getBatteryState();
    return state == BatteryState.charging ||
        state == BatteryState.full ||
        state == BatteryState.connectedNotCharging;
  }

  Future<QualityRecommendation> recommendQuality({
    required QualityMode mode,
    required List<int> availableQualities,
    Uri? probeUri,
  }) async {
    final qualities =
        availableQualities.where((code) => code > 0).toSet().toList()
          ..sort((a, b) => b.compareTo(a));
    if (qualities.isEmpty) {
      return QualityRecommendation.manual(
        mode: mode,
        qualityCode: VideoQualityCode.kAuto,
        qualityLabel: VideoQualityCode.getLabel(VideoQualityCode.kAuto),
      );
    }
    if (qualities.length == 1) {
      final selected = qualities.single;
      return mode == QualityMode.auto
          ? QualityRecommendation.auto(
              qualityCode: selected,
              qualityLabel: VideoQualityCode.getLabel(selected),
              reason: '当前仅此画质可用',
            )
          : QualityRecommendation.manual(
              mode: mode,
              qualityCode: selected,
              qualityLabel: VideoQualityCode.getLabel(selected),
            );
    }

    return switch (mode) {
      QualityMode.qualityFirst => _recommendQualityFirst(qualities),
      QualityMode.smoothFirst => _recommendSmoothFirst(qualities),
      QualityMode.batterySaver => await _recommendBatterySaver(qualities),
      QualityMode.auto => await _recommendAuto(qualities, probeUri),
    };
  }

  QualityRecommendation _recommendQualityFirst(List<int> qualities) {
    final selected = qualities.first;
    return QualityRecommendation.manual(
      mode: QualityMode.qualityFirst,
      qualityCode: selected,
      qualityLabel: VideoQualityCode.getLabel(selected),
    );
  }

  QualityRecommendation _recommendSmoothFirst(List<int> qualities) {
    final selected = _firstAvailable(
      const [
        VideoQualityCode.k720p60,
        VideoQualityCode.k1080p60,
        VideoQualityCode.k720p,
        VideoQualityCode.k480p,
        VideoQualityCode.k360p,
        VideoQualityCode.k240p,
      ],
      qualities,
      fallbackTarget: VideoQualityCode.k720p60,
    );
    return QualityRecommendation.manual(
      mode: QualityMode.smoothFirst,
      qualityCode: selected,
      qualityLabel: VideoQualityCode.getLabel(selected),
      reason: '优先高帧率与稳定播放',
    );
  }

  Future<QualityRecommendation> _recommendBatterySaver(
    List<int> qualities,
  ) async {
    final charging = await isCharging();
    final target = charging ? VideoQualityCode.k720p : VideoQualityCode.k360p;
    final selected = _fallbackAtOrBelow(target, qualities);
    return QualityRecommendation.manual(
      mode: QualityMode.batterySaver,
      qualityCode: selected,
      qualityLabel: VideoQualityCode.getLabel(selected),
      reason: charging ? '充电中，上限 720P' : '降低解码功耗',
    );
  }

  Future<QualityRecommendation> _recommendAuto(
    List<int> qualities,
    Uri? probeUri,
  ) async {
    await init();
    final batteryLevel = await getBatteryLevel();
    final charging = await isCharging();
    final measuredSpeed = await measureNetworkSpeed(probeUri);

    var target = measuredSpeed == null
        ? _heuristicTarget(_lastNetworkType)
        : _targetForSpeed(measuredSpeed);
    if (!charging && batteryLevel < 10) {
      target = _lowerTarget(target, VideoQualityCode.k480p);
    } else if (!charging && batteryLevel < 20) {
      target = _lowerTarget(target, VideoQualityCode.k720p);
    }

    final selected = _fallbackAtOrBelow(target, qualities);
    final reasons = <String>[
      if (_lastNetworkType != NetworkType.none) _lastNetworkType.label,
      if (measuredSpeed != null) '${measuredSpeed.toStringAsFixed(1)} Mbps',
      if (!charging && batteryLevel < 20) '低电量',
    ];
    return QualityRecommendation.auto(
      qualityCode: selected,
      qualityLabel: VideoQualityCode.getLabel(selected),
      reason: reasons.isEmpty ? null : reasons.join(' · '),
    );
  }

  static int _targetForSpeed(double mbps) {
    if (mbps >= 35) return VideoQualityCode.k4k;
    if (mbps >= 18) return VideoQualityCode.k1080p60;
    if (mbps >= 10) return VideoQualityCode.k1080p;
    if (mbps >= 6) return VideoQualityCode.k720p60;
    if (mbps >= 3) return VideoQualityCode.k720p;
    if (mbps >= 1.5) return VideoQualityCode.k480p;
    if (mbps >= 0.7) return VideoQualityCode.k360p;
    return VideoQualityCode.k240p;
  }

  static int _heuristicTarget(NetworkType networkType) => switch (networkType) {
    NetworkType.wifi => VideoQualityCode.k1080p,
    NetworkType.cellular5g => VideoQualityCode.k1080p,
    NetworkType.cellular4g => VideoQualityCode.k720p,
    NetworkType.cellular3g => VideoQualityCode.k480p,
    NetworkType.cellular2g => VideoQualityCode.k360p,
    NetworkType.none => VideoQualityCode.k240p,
  };

  static int _lowerTarget(int target, int ceiling) =>
      target > ceiling ? ceiling : target;

  static int _firstAvailable(
    List<int> preferred,
    List<int> qualities, {
    required int fallbackTarget,
  }) {
    for (final quality in preferred) {
      if (qualities.contains(quality)) return quality;
    }
    return _fallbackAtOrBelow(fallbackTarget, qualities);
  }

  /// Chooses the best supported quality not exceeding [target].
  ///
  /// If every available quality is above the target, the lowest available
  /// stream is selected rather than returning an unsupported qn.
  static int _fallbackAtOrBelow(int target, List<int> qualities) {
    if (qualities.contains(target)) return target;
    for (final quality in qualities) {
      if (quality < target) return quality;
    }
    return qualities.last;
  }

  void clearSpeedCache() => _speedCache = null;

  Future<void> close() async {
    await _networkSubscription?.cancel();
    _networkSubscription = null;
  }
}

class _SpeedCache {
  const _SpeedCache({
    required this.mbps,
    required this.measuredAt,
    required this.networkType,
  });

  final double mbps;
  final DateTime measuredAt;
  final NetworkType networkType;
}
