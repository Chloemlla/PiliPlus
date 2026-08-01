import 'package:pili_plus/models/quality_mode.dart';
import 'package:pili_plus/services/quality_network_speed_probe.dart';
import 'package:pili_plus/services/quality_recommendation_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QualityRecommendationService', () {
    final services = <QualityRecommendationService>[];

    QualityRecommendationService createService({
      NetworkType networkType = NetworkType.wifi,
      int batteryLevel = 80,
      BatteryState batteryState = BatteryState.discharging,
      NetworkSpeedProbe? probe,
      DateTime Function()? clock,
    }) {
      final service = QualityRecommendationService(
        networkTypeReader: () => Future.value(networkType),
        networkTypeChanges: const Stream.empty(),
        batteryLevelReader: () => Future.value(batteryLevel),
        batteryStateReader: () => Future.value(batteryState),
        speedProbe: probe ?? _FakeSpeedProbe(12),
        clock: clock,
      );
      services.add(service);
      return service;
    }

    tearDown(() async {
      for (final service in services) {
        await service.close();
      }
      services.clear();
    });

    test('keeps a shared default instance', () {
      expect(
        identical(
          QualityRecommendationService.instance,
          QualityRecommendationService.instance,
        ),
        isTrue,
      );
    });

    test('returns automatic fallback when no qn is available', () async {
      final result = await createService().recommendQuality(
        mode: QualityMode.auto,
        availableQualities: const [],
      );

      expect(result.qualityCode, VideoQualityCode.kAuto);
      expect(result.qualityLabel, '自动');
    });

    test('quality-first selects the highest actual DASH qn', () async {
      final result = await createService().recommendQuality(
        mode: QualityMode.qualityFirst,
        availableQualities: const [
          VideoQualityCode.k480p,
          VideoQualityCode.k720p,
          VideoQualityCode.k1080p,
          VideoQualityCode.k4k,
        ],
      );

      expect(result.qualityCode, VideoQualityCode.k4k);
      expect(result.isAuto, isFalse);
    });

    test('smooth-first prefers 720P60 before higher resolution', () async {
      final result = await createService().recommendQuality(
        mode: QualityMode.smoothFirst,
        availableQualities: const [
          VideoQualityCode.k720p,
          VideoQualityCode.k720p60,
          VideoQualityCode.k1080p,
          VideoQualityCode.k1080p60,
        ],
      );

      expect(result.qualityCode, VideoQualityCode.k720p60);
      expect(result.mode, QualityMode.smoothFirst);
      expect(result.isAuto, isFalse);
    });

    test('battery saver selects a low stable supported qn', () async {
      final result = await createService().recommendQuality(
        mode: QualityMode.batterySaver,
        availableQualities: const [
          VideoQualityCode.k360p,
          VideoQualityCode.k480p,
          VideoQualityCode.k720p,
          VideoQualityCode.k1080p,
        ],
      );

      expect(result.qualityCode, VideoQualityCode.k360p);
      expect(result.mode, QualityMode.batterySaver);
    });

    test('auto uses measured throughput and never invents a qn', () async {
      final result =
          await createService(
            probe: _FakeSpeedProbe(12),
          ).recommendQuality(
            mode: QualityMode.auto,
            probeUri: Uri.parse('https://example.com/video.m4s'),
            availableQualities: const [
              VideoQualityCode.k480p,
              VideoQualityCode.k720p,
              VideoQualityCode.k1080p,
              VideoQualityCode.k4k,
            ],
          );

      expect(result.qualityCode, VideoQualityCode.k1080p);
      expect(result.reason, contains('12.0 Mbps'));
    });

    test('low battery caps an otherwise high recommendation', () async {
      final result =
          await createService(
            batteryLevel: 15,
            probe: _FakeSpeedProbe(50),
          ).recommendQuality(
            mode: QualityMode.auto,
            probeUri: Uri.parse('https://example.com/video.m4s'),
            availableQualities: const [
              VideoQualityCode.k480p,
              VideoQualityCode.k720p,
              VideoQualityCode.k1080p,
              VideoQualityCode.k4k,
            ],
          );

      expect(result.qualityCode, VideoQualityCode.k720p);
      expect(result.reason, contains('低电量'));
    });

    test('falls back to the next lower available qn', () async {
      final result =
          await createService(
            probe: _FakeSpeedProbe(12),
          ).recommendQuality(
            mode: QualityMode.auto,
            probeUri: Uri.parse('https://example.com/video.m4s'),
            availableQualities: const [
              VideoQualityCode.k720p,
              VideoQualityCode.k4k,
            ],
          );

      expect(result.qualityCode, VideoQualityCode.k720p);
    });

    test('reuses a successful speed probe for five minutes', () async {
      var now = DateTime.utc(2026, 7, 31, 12);
      final probe = _FakeSpeedProbe(8);
      final service = createService(probe: probe, clock: () => now);
      final uri = Uri.parse('https://example.com/video.m4s');

      expect(await service.measureNetworkSpeed(uri), 8);
      now = now.add(const Duration(minutes: 4));
      expect(await service.measureNetworkSpeed(uri), 8);
      expect(probe.callCount, 1);

      now = now.add(const Duration(minutes: 2));
      expect(await service.measureNetworkSpeed(uri), 8);
      expect(probe.callCount, 2);
    });
  });
}

class _FakeSpeedProbe implements NetworkSpeedProbe {
  _FakeSpeedProbe(this.mbps);

  final double? mbps;
  int callCount = 0;

  @override
  Future<double?> measure(
    Uri uri, {
    required Duration maxDuration,
  }) {
    callCount++;
    return Future.value(mbps);
  }
}
