import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/quality_mode.dart';

void main() {
  group('QualityMode', () {
    test('should have correct values', () {
      expect(QualityMode.values.length, 4);
      expect(QualityMode.values, contains(QualityMode.qualityFirst));
      expect(QualityMode.values, contains(QualityMode.smoothFirst));
      expect(QualityMode.values, contains(QualityMode.batterySaver));
      expect(QualityMode.values, contains(QualityMode.auto));
    });

    test('should have correct labels', () {
      expect(QualityMode.qualityFirst.label, '画质优先');
      expect(QualityMode.smoothFirst.label, '流畅优先');
      expect(QualityMode.batterySaver.label, '省电模式');
      expect(QualityMode.auto.label, '自动');
    });

    test('should have descriptions', () {
      expect(QualityMode.qualityFirst.description, isNotEmpty);
      expect(QualityMode.smoothFirst.description, isNotEmpty);
      expect(QualityMode.batterySaver.description, isNotEmpty);
      expect(QualityMode.auto.description, isNotEmpty);
    });
  });

  group('VideoQualityCode', () {
    test('should return correct labels', () {
      expect(VideoQualityCode.getLabel(VideoQualityCode.k4k), '4K');
      expect(VideoQualityCode.getLabel(VideoQualityCode.k1080p60), '1080P60');
      expect(VideoQualityCode.getLabel(VideoQualityCode.k1080p), '1080P');
      expect(VideoQualityCode.getLabel(VideoQualityCode.k720p), '720P');
      expect(VideoQualityCode.getLabel(VideoQualityCode.k720p60), '720P60');
      expect(VideoQualityCode.getLabel(VideoQualityCode.k480p), '480P');
      expect(VideoQualityCode.getLabel(VideoQualityCode.k360p), '360P');
      expect(VideoQualityCode.getLabel(VideoQualityCode.k240p), '240P');
      expect(VideoQualityCode.getLabel(VideoQualityCode.kAuto), '自动');
      expect(VideoQualityCode.getLabel(999), '未知');
    });

    test('should convert labels to codes', () {
      expect(VideoQualityCode.fromLabel('4K'), VideoQualityCode.k4k);
      expect(VideoQualityCode.fromLabel('1080P60'), VideoQualityCode.k1080p60);
      expect(VideoQualityCode.fromLabel('1080P'), VideoQualityCode.k1080p);
      expect(VideoQualityCode.fromLabel('720P'), VideoQualityCode.k720p);
      expect(VideoQualityCode.fromLabel('720P60'), VideoQualityCode.k720p60);
      expect(VideoQualityCode.fromLabel('480P'), VideoQualityCode.k480p);
      expect(VideoQualityCode.fromLabel('360P'), VideoQualityCode.k360p);
      expect(VideoQualityCode.fromLabel('240P'), VideoQualityCode.k240p);
      expect(VideoQualityCode.fromLabel('自动'), VideoQualityCode.kAuto);
      expect(VideoQualityCode.fromLabel('Unknown'), null);
    });
  });

  group('NetworkType', () {
    test('should have correct values', () {
      expect(NetworkType.values.length, 6);
    });

    test('should have correct labels', () {
      expect(NetworkType.wifi.label, 'WiFi');
      expect(NetworkType.cellular5g.label, '5G');
      expect(NetworkType.cellular4g.label, '4G');
      expect(NetworkType.cellular3g.label, '3G');
      expect(NetworkType.cellular2g.label, '2G');
      expect(NetworkType.none.label, '无网络');
    });

    test('should have correct quality tiers', () {
      expect(NetworkType.wifi.qualityTier, 5);
      expect(NetworkType.cellular5g.qualityTier, 4);
      expect(NetworkType.cellular4g.qualityTier, 3);
      expect(NetworkType.cellular3g.qualityTier, 2);
      expect(NetworkType.cellular2g.qualityTier, 0);
      expect(NetworkType.none.qualityTier, 0);
    });
  });

  group('QualityRecommendation', () {
    test('should create auto recommendation', () {
      final rec = QualityRecommendation.auto(
        qualityCode: VideoQualityCode.k1080p,
        qualityLabel: '1080P',
        reason: 'WiFi | 50 Mbps',
      );

      expect(rec.qualityCode, VideoQualityCode.k1080p);
      expect(rec.qualityLabel, '1080P');
      expect(rec.reason, 'WiFi | 50 Mbps');
      expect(rec.isAuto, true);
    });

    test('should create manual recommendation', () {
      final rec = QualityRecommendation.manual(
        qualityCode: VideoQualityCode.k4k,
        qualityLabel: '4K',
      );

      expect(rec.qualityCode, VideoQualityCode.k4k);
      expect(rec.qualityLabel, '4K');
      expect(rec.reason, null);
      expect(rec.isAuto, false);
    });
  });
}
