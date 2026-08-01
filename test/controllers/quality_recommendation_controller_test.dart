import 'package:pili_plus/controllers/quality_recommendation_controller.dart';
import 'package:pili_plus/models/quality_mode.dart';
import 'package:pili_plus/services/quality_network_speed_probe.dart';
import 'package:pili_plus/services/quality_recommendation_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  QualityRecommendationService createService({double speed = 12}) =>
      QualityRecommendationService(
        networkTypeReader: () => Future.value(NetworkType.wifi),
        networkTypeChanges: const Stream.empty(),
        batteryLevelReader: () => Future.value(80),
        batteryStateReader: () => Future.value(BatteryState.discharging),
        speedProbe: _FixedSpeedProbe(speed),
      );

  test('invalid persisted mode safely falls back to auto', () {
    final controller = QualityRecommendationController(
      modeReader: () => 999,
      modeWriter: (_) => Future<void>.value(),
    );

    expect(controller.currentMode.value, QualityMode.auto);
    controller.dispose();
  });

  test('publishes a mode only after its stable value is persisted', () async {
    final stored = <String>[];
    final controller = QualityRecommendationController(
      modeReader: () => 3,
      modeWriter: (value) {
        stored.add(value);
        return Future<void>.value();
      },
    );

    await controller.setMode(QualityMode.qualityFirst);

    expect(stored, const ['qualityFirst']);
    expect(controller.currentMode.value, QualityMode.qualityFirst);
    controller.dispose();
  });

  test('failed persistence leaves the active mode unchanged', () async {
    final controller = QualityRecommendationController(
      modeReader: () => QualityMode.auto.storageValue,
      modeWriter: (_) => Future<void>.error(StateError('write failed')),
    );

    await expectLater(
      controller.setMode(QualityMode.batterySaver),
      throwsStateError,
    );
    expect(controller.currentMode.value, QualityMode.auto);
    controller.dispose();
  });

  test(
    'applies an actual qn and shows the auto chip for three-second seam',
    () async {
      final applied = <int>[];
      final service = createService();
      final controller = QualityRecommendationController(
        service: service,
        modeReader: () => QualityMode.auto.storageValue,
        modeWriter: (_) => Future<void>.value(),
        chipDisplayDuration: const Duration(milliseconds: 5),
        onApplyQuality: (qualityCode) {
          applied.add(qualityCode);
          return true;
        },
      );

      final recommendation = await controller.setAvailableQualities(
        const [VideoQualityCode.k720p, VideoQualityCode.k1080p],
        probeUri: Uri.parse('https://example.com/video.m4s'),
        currentQualityCode: VideoQualityCode.k720p,
        applyToPlayer: true,
      );

      expect(recommendation?.qualityCode, VideoQualityCode.k1080p);
      expect(applied, const [VideoQualityCode.k1080p]);
      expect(controller.showQualityChip.value, isFalse);

      controller.onPlaybackReady(VideoQualityCode.k1080p);
      expect(controller.showQualityChip.value, isTrue);
      expect(controller.qualityChipMessage.value, '自动：720P → 1080P');

      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(controller.showQualityChip.value, isFalse);

      controller.dispose();
      await service.close();
    },
  );
}

class _FixedSpeedProbe implements NetworkSpeedProbe {
  const _FixedSpeedProbe(this.speed);

  final double speed;

  @override
  Future<double?> measure(
    Uri uri, {
    required Duration maxDuration,
  }) => Future.value(speed);
}
