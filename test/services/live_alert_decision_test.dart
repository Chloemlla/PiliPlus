import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';
import 'package:pili_plus/services/live_alert_data_source.dart';
import 'package:pili_plus/services/live_alert_decision.dart';

void main() {
  group('chooseLiveAlertDecision', () {
    const snapshot = LiveAlertRoomSnapshot(
      mid: 100,
      roomId: 200,
      upName: 'UP',
      avatarUrl: '',
      liveStatus: 1,
      title: 'Late Night Concert',
      areaName: 'Music',
    );

    test('returns only the first stable match when multiple rules match', () {
      final decision = chooseLiveAlertDecision(
        rules: [
          _rule(id: 'newer', keyword: 'music', createdAt: 2),
          _rule(id: 'older', keyword: 'concert', createdAt: 1),
        ],
        snapshot: snapshot,
      );

      expect(decision?.rule.id, 'older');
      expect(decision?.matchedKeyword, 'concert');
    });

    test('ignores disabled and empty-keyword rules', () {
      final decision = chooseLiveAlertDecision(
        rules: [
          _rule(id: 'disabled', keyword: 'concert', enabled: false),
          _rule(id: 'empty', keyword: '   '),
        ],
        snapshot: snapshot,
      );

      expect(decision, isNull);
    });
  });

  group('isLiveAlertRateLimited', () {
    test('uses one cooldown ledger timestamp per account and UP', () {
      expect(
        isLiveAlertRateLimited(
          lastNotifiedAt: 1000,
          nowSeconds: 1000 + const Duration(hours: 3).inSeconds,
          cooldown: const Duration(hours: 4),
        ),
        isTrue,
      );
      expect(
        isLiveAlertRateLimited(
          lastNotifiedAt: 1000,
          nowSeconds: 1000 + const Duration(hours: 4).inSeconds,
          cooldown: const Duration(hours: 4),
        ),
        isFalse,
      );
    });
  });
}

LiveKeywordRule _rule({
  required String id,
  required String keyword,
  int createdAt = 1,
  bool enabled = true,
}) => LiveKeywordRule(
  id: id,
  mid: 100,
  upName: 'UP',
  keyword: keyword,
  matchTargetIndex: MatchTarget.both.index,
  enabled: enabled,
  createdAt: createdAt,
  accountMid: 10,
);
