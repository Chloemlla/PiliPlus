/// Video quality modes for smart recommendation
enum QualityMode {
  /// Always prefer the highest available quality
  qualityFirst,

  /// Prefer lower resolution with higher frame rate
  smoothFirst,

  /// Prefer lowest stable resolution to save battery
  batterySaver,

  /// Smart recommendation based on network and battery
  auto,
}

extension QualityModeExtension on QualityMode {
  String get label {
    switch (this) {
      case QualityMode.qualityFirst:
        return '画质优先';
      case QualityMode.smoothFirst:
        return '流畅优先';
      case QualityMode.batterySaver:
        return '省电模式';
      case QualityMode.auto:
        return '自动';
    }
  }

  String get description {
    switch (this) {
      case QualityMode.qualityFirst:
        return '始终使用最高画质';
      case QualityMode.smoothFirst:
        return '优先保证流畅度';
      case QualityMode.batterySaver:
        return '降低画质以节省电量';
      case QualityMode.auto:
        return '根据网络和电量智能推荐';
    }
  }
}

/// Bilibili quality codes mapping
class VideoQualityCode {
  static const int k4k = 120;
  static const int k1080p60 = 116;
  static const int k1080p = 112;
  static const int k720p = 80;
  static const int k720p60 = 74;
  static const int k480p = 64;
  static const int k360p = 32;
  static const int k240p = 16;
  static const int kAuto = 0;

  /// Get label for quality code
  static String getLabel(int code) {
    switch (code) {
      case k4k:
        return '4K';
      case k1080p60:
        return '1080P60';
      case k1080p:
        return '1080P';
      case k720p:
        return '720P';
      case k720p60:
        return '720P60';
      case k480p:
        return '480P';
      case k360p:
        return '360P';
      case k240p:
        return '240P';
      case kAuto:
        return '自动';
      default:
        return '未知';
    }
  }

  /// Get quality code from label
  static int? fromLabel(String label) {
    switch (label) {
      case '4K':
        return k4k;
      case '1080P60':
        return k1080p60;
      case '1080P':
        return k1080p;
      case '720P':
        return k720p;
      case '720P60':
        return k720p60;
      case '480P':
        return k480p;
      case '360P':
        return k360p;
      case '240P':
        return k240p;
      case '自动':
        return kAuto;
      default:
        return null;
    }
  }
}

/// Network type for quality recommendation
enum NetworkType {
  wifi,
  cellular5g,
  cellular4g,
  cellular3g,
  cellular2g,
  none,
}

extension NetworkTypeExtension on NetworkType {
  String get label {
    switch (this) {
      case NetworkType.wifi:
        return 'WiFi';
      case NetworkType.cellular5g:
        return '5G';
      case NetworkType.cellular4g:
        return '4G';
      case NetworkType.cellular3g:
        return '3G';
      case NetworkType.cellular2g:
        return '2G';
      case NetworkType.none:
        return '无网络';
    }
  }

  /// Get recommended quality tier (0-5, higher = better quality)
  int get qualityTier {
    switch (this) {
      case NetworkType.wifi:
        return 5;
      case NetworkType.cellular5g:
        return 4;
      case NetworkType.cellular4g:
        return 3;
      case NetworkType.cellular3g:
        return 2;
      case NetworkType.cellular2g:
      case NetworkType.none:
        return 0;
    }
  }
}

/// Quality recommendation result
class QualityRecommendation {
  final int qualityCode;
  final String qualityLabel;
  final String? reason;
  final bool isAuto;

  QualityRecommendation({
    required this.qualityCode,
    required this.qualityLabel,
    this.reason,
    this.isAuto = false,
  });

  factory QualityRecommendation.auto({
    required int qualityCode,
    required String qualityLabel,
    String? reason,
  }) {
    return QualityRecommendation(
      qualityCode: qualityCode,
      qualityLabel: qualityLabel,
      reason: reason,
      isAuto: true,
    );
  }

  factory QualityRecommendation.manual({
    required int qualityCode,
    required String qualityLabel,
  }) {
    return QualityRecommendation(
      qualityCode: qualityCode,
      qualityLabel: qualityLabel,
      isAuto: false,
    );
  }
}
