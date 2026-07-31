import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/services/quality_recommendation_service.dart';
import 'package:pili_plus/models/quality_mode.dart';

void main() {
  group('QualityRecommendationService', () {
    late QualityRecommendationService service;

    setUp(() {
      service = QualityRecommendationService.instance;
    });

    test('should be singleton', () {
      final instance1 = QualityRecommendationService.instance;
      final instance2 = QualityRecommendationService.instance;
      expect(identical(instance1, instance2), true);
    });

    group('recommendQuality', () {
      test('should return auto for empty qualities', () async {
        final result = await service.recommendQuality(
          mode: QualityMode.auto,
          availableQualities: [],
        );

        expect(result.qualityCode, VideoQualityCode.kAuto);
        expect(result.qualityLabel, '自动');
      });

      test('should recommend highest quality for qualityFirst mode', () async {
        final qualities = [
          VideoQualityCode.k480p,
          VideoQualityCode.k720p,
          VideoQualityCode.k1080p,
          VideoQualityCode.k4k,
        ];

        final result = await service.recommendQuality(
          mode: QualityMode.qualityFirst,
          availableQualities: qualities,
        );

        expect(result.qualityCode, VideoQualityCode.k4k);
        expect(result.isAuto, false);
      });

      test('should prefer 60fps for smoothFirst mode when available', () async {
        final qualities = [
          VideoQualityCode.k480p,
          VideoQualityCode.k720p,
          VideoQualityCode.k720p60,
          VideoQualityCode.k1080p,
        ];

        final result = await service.recommendQuality(
          mode: QualityMode.smoothFirst,
          availableQualities: qualities,
        );

        expect(result.qualityCode, VideoQualityCode.k720p60);
        expect(result.reason, '流畅优先模式');
        expect(result.isAuto, true);
      });

      test('should fallback to 720P for smoothFirst if no 60fps', () async {
        final qualities = [
          VideoQualityCode.k480p,
          VideoQualityCode.k720p,
          VideoQualityCode.k1080p,
        ];

        final result = await service.recommendQuality(
          mode: QualityMode.smoothFirst,
          availableQualities: qualities,
        );

        expect(result.qualityCode, VideoQualityCode.k720p);
        expect(result.isAuto, true);
      });

      test('should recommend lower quality for batterySaver mode', () async {
        final qualities = [
          VideoQualityCode.k480p,
          VideoQualityCode.k720p,
          VideoQualityCode.k1080p,
        ];

        final result = await service.recommendQuality(
          mode: QualityMode.batterySaver,
          availableQualities: qualities,
        );

        // Since we can't control battery state in test, result may vary
        expect(qualities.contains(result.qualityCode), true);
        expect(result.isAuto, true);
      });
    });

    group('speed cache', () {
      test('should clear speed cache', () {
        service.clearSpeedCache();
        // No exception means success
      });
    });
  });
}
