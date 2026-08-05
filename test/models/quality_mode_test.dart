import 'package:pili_plus/models/common/video/video_quality.dart';
import 'package:pili_plus/models/quality_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QualityMode', () {
    test('exposes the four user-facing modes', () {
      expect(QualityMode.values, const [
        QualityMode.qualityFirst,
        QualityMode.smoothFirst,
        QualityMode.batterySaver,
        QualityMode.auto,
      ]);
      for (final mode in QualityMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
    });

    test('decodes stable and legacy persisted values defensively', () {
      expect(QualityModeCodec.decode('qualityFirst'), QualityMode.qualityFirst);
      expect(QualityModeCodec.decode('流畅优先'), QualityMode.smoothFirst);
      expect(QualityModeCodec.decode(2), QualityMode.batterySaver);
      expect(QualityModeCodec.decode('3'), QualityMode.auto);
      expect(QualityModeCodec.decode(-1), QualityMode.auto);
      expect(QualityModeCodec.decode(999), QualityMode.auto);
      expect(
        QualityModeCodec.decode(const {'invalid': true}),
        QualityMode.auto,
      );
    });
  });

  group('VideoQualityCode', () {
    test('matches the player API qn mapping', () {
      expect(VideoQualityCode.k1080pPlus, VideoQuality.high1080plus.code);
      expect(VideoQualityCode.k1080p, VideoQuality.high1080.code);
      expect(VideoQualityCode.k720p, VideoQuality.high720.code);
      expect(VideoQualityCode.k480p, VideoQuality.clear480.code);
      expect(VideoQualityCode.k360p, VideoQuality.fluent360.code);
      expect(VideoQualityCode.k240p, VideoQuality.speed240.code);
      expect(VideoQualityCode.getLabel(112), '1080P+');
      expect(VideoQualityCode.getLabel(80), '1080P');
      expect(VideoQualityCode.getLabel(64), '720P');
    });

    test('round trips supported labels', () {
      for (final entry in const <String, int>{
        '4K': VideoQualityCode.k4k,
        '1080P60': VideoQualityCode.k1080p60,
        '1080P+': VideoQualityCode.k1080pPlus,
        '1080P': VideoQualityCode.k1080p,
        '720P60': VideoQualityCode.k720p60,
        '720P': VideoQualityCode.k720p,
        '480P': VideoQualityCode.k480p,
        '360P': VideoQualityCode.k360p,
        '240P': VideoQualityCode.k240p,
        '自动': VideoQualityCode.kAuto,
      }.entries) {
        expect(VideoQualityCode.fromLabel(entry.key), entry.value);
        expect(VideoQualityCode.getLabel(entry.value), entry.key);
      }
      expect(VideoQualityCode.fromLabel('unknown'), isNull);
      expect(VideoQualityCode.getLabel(999), '未知');
    });
  });

  group('QualityRecommendation', () {
    test('derives automatic state from the originating mode', () {
      final automatic = QualityRecommendation.auto(
        qualityCode: VideoQualityCode.k1080p,
        qualityLabel: '1080P',
        reason: 'WiFi · 50.0 Mbps',
      );
      final manual = QualityRecommendation.manual(
        mode: QualityMode.smoothFirst,
        qualityCode: VideoQualityCode.k720p60,
        qualityLabel: '720P60',
      );

      expect(automatic.isAuto, isTrue);
      expect(automatic.mode, QualityMode.auto);
      expect(manual.isAuto, isFalse);
      expect(manual.mode, QualityMode.smoothFirst);
    });
  });
}
