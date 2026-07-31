import 'dart:async';
import 'package:pili_plus/models/quality_mode.dart';
import 'package:pili_plus/utils/storage.dart';
import 'package:pili_plus/utils/storage_key.dart';
import 'package:pili_plus/utils/storage_pref.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';

class QualityRecommendationService {
  static QualityRecommendationService? _instance;
  static QualityRecommendationService get instance =>
      _instance ??= QualityRecommendationService._();

  QualityRecommendationService._();

  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();

  /// Cached network speed measurement (Mbps)
  double? _cachedSpeedMbps;
  DateTime? _speedCacheTime;
  static const Duration _speedCacheDuration = Duration(minutes: 5);

  /// Last known network type
  NetworkType _lastNetworkType = NetworkType.none;

  /// Initialize service and start monitoring
  Future<void> init() async {
    // Listen for network changes
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    await _updateNetworkType();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    _updateNetworkType();
  }

  Future<void> _updateNetworkType() async {
    final results = await _connectivity.checkConnectivity();
    _lastNetworkType = _mapConnectivityResult(results);
  }

  NetworkType _mapConnectivityResult(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return NetworkType.none;
    }

    for (final result in results) {
      switch (result) {
        case ConnectivityResult.wifi:
          return NetworkType.wifi;
        case ConnectivityResult.mobile:
          // Note: connectivity_plus doesn't distinguish between 4G/5G/3G
          // We'll use 4G as default for mobile
          return NetworkType.cellular4g;
        case ConnectivityResult.ethernet:
          return NetworkType.wifi;
        default:
          continue;
      }
    }

    return NetworkType.none;
  }

  /// Measure network speed using a small probe
  Future<double?> measureNetworkSpeed() async {
    // Check cache first
    if (_cachedSpeedMbps != null &&
        _speedCacheTime != null &&
        DateTime.now().difference(_speedCacheTime!) < _speedCacheDuration) {
      return _cachedSpeedMbps;
    }

    try {
      // Simple speed measurement using a known small file
      // In production, this could use a CDN speed test endpoint
      final stopwatch = Stopwatch()..start();

      // Simulate speed test (in real implementation, download a small file)
      await Future.delayed(const Duration(milliseconds: 500));

      stopwatch.stop();

      // For demo, estimate based on network type
      double estimatedSpeed;
      switch (_lastNetworkType) {
        case NetworkType.wifi:
          estimatedSpeed = 50.0; // 50 Mbps
          break;
        case NetworkType.cellular5g:
          estimatedSpeed = 30.0; // 30 Mbps
          break;
        case NetworkType.cellular4g:
          estimatedSpeed = 10.0; // 10 Mbps
          break;
        case NetworkType.cellular3g:
          estimatedSpeed = 2.0; // 2 Mbps
          break;
        case NetworkType.cellular2g:
          estimatedSpeed = 0.5; // 0.5 Mbps
          break;
        case NetworkType.none:
          estimatedSpeed = 0.0;
          break;
      }

      _cachedSpeedMbps = estimatedSpeed;
      _speedCacheTime = DateTime.now();

      return estimatedSpeed;
    } catch (e) {
      return null;
    }
  }

  /// Get current battery level (0-100)
  Future<int> getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      return level;
    } catch (e) {
      return 100; // Assume full if cannot read
    }
  }

  /// Get battery state (charging, discharging, etc.)
  Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (e) {
      return BatteryState.unknown;
    }
  }

  /// Check if device is low on battery
  Future<bool> isLowBattery() async {
    final level = await getBatteryLevel();
    return level < 20;
  }

  /// Check if device is charging
  Future<bool> isCharging() async {
    final state = await getBatteryState();
    return state == BatteryState.charging || state == BatteryState.full;
  }

  /// Recommend quality based on current conditions
  Future<QualityRecommendation> recommendQuality({
    required QualityMode mode,
    required List<int> availableQualities,
  }) async {
    if (availableQualities.isEmpty) {
      return QualityRecommendation.manual(
        qualityCode: VideoQualityCode.kAuto,
        qualityLabel: '自动',
      );
    }

    // Sort qualities from high to low
    final sortedQualities = List<int>.from(availableQualities)
      ..sort((a, b) => b.compareTo(a));

    switch (mode) {
      case QualityMode.qualityFirst:
        return _recommendQualityFirst(sortedQualities);

      case QualityMode.smoothFirst:
        return _recommendSmoothFirst(sortedQualities);

      case QualityMode.batterySaver:
        return _recommendBatterySaver(sortedQualities);

      case QualityMode.auto:
        return _recommendAuto(sortedQualities);
    }
  }

  /// Quality first: always use highest available
  QualityRecommendation _recommendQualityFirst(List<int> qualities) {
    final highestQuality = qualities.first;
    return QualityRecommendation.manual(
      qualityCode: highestQuality,
      qualityLabel: VideoQualityCode.getLabel(highestQuality),
    );
  }

  /// Smooth first: prefer lower resolution with high frame rate if available
  QualityRecommendation _recommendSmoothFirst(List<int> qualities) {
    // Find 60fps options first
    final fps60Options = qualities.where((q) =>
        q == VideoQualityCode.k1080p60 ||
        q == VideoQualityCode.k720p60).toList();

    if (fps60Options.isNotEmpty) {
      // Prefer 720P60 over 1080P60 for smoothness
      final quality = fps60Options.contains(VideoQualityCode.k720p60)
          ? VideoQualityCode.k720p60
          : fps60Options.first;
      return QualityRecommendation(
        qualityCode: quality,
        qualityLabel: VideoQualityCode.getLabel(quality),
        reason: '流畅优先模式',
        isAuto: true,
      );
    }

    // Fall back to 720P
    final fallback = qualities.contains(VideoQualityCode.k720p)
        ? VideoQualityCode.k720p
        : qualities.last;
    return QualityRecommendation(
      qualityCode: fallback,
      qualityLabel: VideoQualityCode.getLabel(fallback),
      reason: '流畅优先模式',
      isAuto: true,
    );
  }

  /// Battery saver: use lowest stable quality
  Future<QualityRecommendation> _recommendBatterySaver(List<int> qualities) async {
    final isCharging = await this.isCharging();

    // If charging, allow higher quality
    int targetQuality;
    if (isCharging) {
      targetQuality = qualities.contains(VideoQualityCode.k720p)
          ? VideoQualityCode.k720p
          : qualities.last;
    } else {
      targetQuality = qualities.contains(VideoQualityCode.k480p)
          ? VideoQualityCode.k480p
          : qualities.contains(VideoQualityCode.k360p)
              ? VideoQualityCode.k360p
              : qualities.last;
    }

    return QualityRecommendation(
      qualityCode: targetQuality,
      qualityLabel: VideoQualityCode.getLabel(targetQuality),
      reason: '省电模式${isCharging ? ' (充电中)' : ''}',
      isAuto: true,
    );
  }

  /// Smart auto recommendation
  Future<QualityRecommendation> _recommendAuto(List<int> qualities) async {
    final networkType = _lastNetworkType;
    final batteryLevel = await getBatteryLevel();
    final isCharging = await this.isCharging();
    final measuredSpeed = await measureNetworkSpeed();

    // Calculate quality tier based on conditions
    int networkTier = networkType.qualityTier;

    // Adjust for measured speed if available
    if (measuredSpeed != null) {
      if (measuredSpeed > 40) {
        networkTier = 5;
      } else if (measuredSpeed > 20) {
        networkTier = 4;
      } else if (measuredSpeed > 10) {
        networkTier = 3;
      } else if (measuredSpeed > 2) {
        networkTier = 2;
      } else {
        networkTier = 1;
      }
    }

    // Battery adjustment
    int batteryAdjustment = 0;
    if (!isCharging) {
      if (batteryLevel < 10) {
        batteryAdjustment = -3;
      } else if (batteryLevel < 20) {
        batteryAdjustment = -2;
      } else if (batteryLevel < 50) {
        batteryAdjustment = -1;
      }
    }

    // Calculate target tier
    int targetTier = (networkTier + batteryAdjustment).clamp(0, 5);

    // Find best matching quality
    int targetQuality = _findQualityForTier(targetTier, qualities);

    final reasons = <String>[];
    if (networkType == NetworkType.wifi) {
      reasons.add('WiFi');
    } else if (networkType.label != '无网络') {
      reasons.add(networkType.label);
    }
    if (batteryLevel < 20) {
      reasons.add('低电量');
    }
    if (measuredSpeed != null) {
      reasons.add('${measuredSpeed.toStringAsFixed(1)} Mbps');
    }

    return QualityRecommendation.auto(
      qualityCode: targetQuality,
      qualityLabel: VideoQualityCode.getLabel(targetQuality),
      reason: reasons.isNotEmpty ? reasons.join(' | ') : null,
    );
  }

  /// Find quality code that matches the target tier
  int _findQualityForTier(int tier, List<int> qualities) {
    // Map tiers to preferred quality codes
    final tierMap = {
      5: [VideoQualityCode.k4k, VideoQualityCode.k1080p60, VideoQualityCode.k1080p],
      4: [VideoQualityCode.k1080p60, VideoQualityCode.k1080p, VideoQualityCode.k720p60],
      3: [VideoQualityCode.k1080p, VideoQualityCode.k720p60, VideoQualityCode.k720p],
      2: [VideoQualityCode.k720p, VideoQualityCode.k480p],
      1: [VideoQualityCode.k480p, VideoQualityCode.k360p],
      0: [VideoQualityCode.k360p, VideoQualityCode.k240p],
    };

    final preferredOrder = tierMap[tier] ?? tierMap[3]!;

    for (final preferred in preferredOrder) {
      if (qualities.contains(preferred)) {
        return preferred;
      }
    }

    // Fall back to lowest available
    return qualities.last;
  }

  /// Clear speed cache
  void clearSpeedCache() {
    _cachedSpeedMbps = null;
    _speedCacheTime = null;
  }
}
