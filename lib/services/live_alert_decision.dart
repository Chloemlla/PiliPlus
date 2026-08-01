import 'package:pili_plus/models/live_keyword_rule.dart';
import 'package:pili_plus/services/live_alert_data_source.dart';

class LiveAlertDecision {
  const LiveAlertDecision({
    required this.rule,
    required this.matchedKeyword,
  });

  final LiveKeywordRule rule;
  final String matchedKeyword;
}

LiveAlertDecision? chooseLiveAlertDecision({
  required Iterable<LiveKeywordRule> rules,
  required LiveAlertRoomSnapshot snapshot,
}) {
  if (!snapshot.isLive) return null;

  final orderedRules = rules.where((rule) => rule.enabled).toList()
    ..sort((a, b) {
      final createdAtCompare = a.createdAt.compareTo(b.createdAt);
      return createdAtCompare != 0 ? createdAtCompare : a.id.compareTo(b.id);
    });

  for (final rule in orderedRules) {
    if (rule.matches(
      streamTitle: snapshot.title,
      areaName: snapshot.areaName,
    )) {
      return LiveAlertDecision(
        rule: rule,
        matchedKeyword: rule.keyword.trim(),
      );
    }
  }
  return null;
}

bool isLiveAlertRateLimited({
  required int lastNotifiedAt,
  required int nowSeconds,
  required Duration cooldown,
}) {
  if (lastNotifiedAt <= 0) return false;
  return nowSeconds - lastNotifiedAt < cooldown.inSeconds;
}
