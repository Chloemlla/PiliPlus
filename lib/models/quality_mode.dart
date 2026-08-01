/// Video quality modes for smart recommendation.
enum QualityMode {
  /// Always prefer the highest available quality.
  qualityFirst,

  /// Prefer a stable high-frame-rate stream without maximizing resolution.
  smoothFirst,

  /// Prefer the lowest stable resolution to reduce power consumption.
  batterySaver,

  /// Recommend a quality from the current network and battery conditions.
  auto,
}

extension QualityModeExtension on QualityMode {
  String get label => switch (this) {
    QualityMode.qualityFirst => '画质优先',
    QualityMode.smoothFirst => '流畅优先',
    QualityMode.batterySaver => '省电模式',
    QualityMode.auto => '自动',
  };

  String get description => switch (this) {
    QualityMode.qualityFirst => '始终使用当前可用的最高画质',
    QualityMode.smoothFirst => '优先选择稳定的高帧率画质',
    QualityMode.batterySaver => '降低分辨率以减少解码功耗',
    QualityMode.auto => '根据实测网速和电量智能推荐',
  };

  /// Stable value used by persistent storage.
  String get storageValue => name;
}

/// Backwards-compatible decoding for the persisted quality mode.
abstract final class QualityModeCodec {
  static QualityMode decode(Object? value) {
    if (value is String) {
      final normalized = value.trim();
      for (final mode in QualityMode.values) {
        if (mode.name == normalized || mode.label == normalized) {
          return mode;
        }
      }
      final legacyIndex = int.tryParse(normalized);
      if (legacyIndex != null) {
        return _fromLegacyIndex(legacyIndex);
      }
    } else if (value is num && value.isFinite) {
      return _fromLegacyIndex(value.toInt());
    }
    return QualityMode.auto;
  }

  static QualityMode _fromLegacyIndex(int index) =>
      index >= 0 && index < QualityMode.values.length
      ? QualityMode.values[index]
      : QualityMode.auto;
}

/// Bilibili on-demand quality codes used by the player API.
///
/// These values intentionally match `VideoQuality` in
/// `models/common/video/video_quality.dart`. In particular, 80 is 1080P and
/// 64 is 720P; treating them as 720P and 480P selects the wrong DASH stream.
abstract final class VideoQualityCode {
  static const int kHdrVivid = 129;
  static const int k8k = 127;
  static const int kDolbyVision = 126;
  static const int kHdr = 125;
  static const int k4k = 120;
  static const int k1080p60 = 116;
  static const int k1080pPlus = 112;
  static const int k1080p = 80;
  static const int k720p60 = 74;
  static const int k720p = 64;
  static const int k480p = 32;
  static const int k360p = 16;
  static const int k240p = 6;
  static const int kAuto = 0;

  static String getLabel(int code) => switch (code) {
    kHdrVivid => 'HDR Vivid',
    k8k => '8K',
    kDolbyVision => '杜比',
    kHdr => 'HDR',
    k4k => '4K',
    k1080p60 => '1080P60',
    k1080pPlus => '1080P+',
    k1080p => '1080P',
    k720p60 => '720P60',
    k720p => '720P',
    k480p => '480P',
    k360p => '360P',
    k240p => '240P',
    kAuto => '自动',
    _ => '未知',
  };

  static int? fromLabel(String label) => switch (label) {
    'HDR Vivid' => kHdrVivid,
    '8K' => k8k,
    '杜比' || '杜比视界' => kDolbyVision,
    'HDR' => kHdr,
    '4K' => k4k,
    '1080P60' => k1080p60,
    '1080P+' => k1080pPlus,
    '1080P' => k1080p,
    '720P60' => k720p60,
    '720P' => k720p,
    '480P' => k480p,
    '360P' => k360p,
    '240P' => k240p,
    '自动' => kAuto,
    _ => null,
  };
}

/// Coarse network type used when a CDN speed probe is unavailable.
enum NetworkType {
  wifi,
  cellular5g,
  cellular4g,
  cellular3g,
  cellular2g,
  none,
}

extension NetworkTypeExtension on NetworkType {
  String get label => switch (this) {
    NetworkType.wifi => 'WiFi',
    NetworkType.cellular5g => '5G',
    NetworkType.cellular4g => '4G',
    NetworkType.cellular3g => '3G',
    NetworkType.cellular2g => '2G',
    NetworkType.none => '无网络',
  };

  int get qualityTier => switch (this) {
    NetworkType.wifi => 5,
    NetworkType.cellular5g => 4,
    NetworkType.cellular4g => 3,
    NetworkType.cellular3g => 2,
    NetworkType.cellular2g || NetworkType.none => 0,
  };
}

/// Result produced by the quality recommendation engine.
class QualityRecommendation {
  const QualityRecommendation({
    required this.mode,
    required this.qualityCode,
    required this.qualityLabel,
    this.reason,
  });

  factory QualityRecommendation.auto({
    required int qualityCode,
    required String qualityLabel,
    String? reason,
  }) => QualityRecommendation(
    mode: QualityMode.auto,
    qualityCode: qualityCode,
    qualityLabel: qualityLabel,
    reason: reason,
  );

  factory QualityRecommendation.manual({
    required int qualityCode,
    required String qualityLabel,
    QualityMode mode = QualityMode.qualityFirst,
    String? reason,
  }) => QualityRecommendation(
    mode: mode,
    qualityCode: qualityCode,
    qualityLabel: qualityLabel,
    reason: reason,
  );

  final QualityMode mode;
  final int qualityCode;
  final String qualityLabel;
  final String? reason;

  bool get isAuto => mode == QualityMode.auto;
}
