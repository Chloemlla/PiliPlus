import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/live_keyword_rule.dart';

void main() {
  group('LiveKeywordRule', () {
    test('creates from constructor', () {
      final rule = LiveKeywordRule(
        id: 'test_id',
        mid: 12345678,
        upName: 'Test UP',
        keyword: '演唱会',
        matchTargetIndex: 0,
        enabled: true,
        createdAt: 1234567890,
      );

      expect(rule.id, 'test_id');
      expect(rule.mid, 12345678);
      expect(rule.upName, 'Test UP');
      expect(rule.keyword, '演唱会');
      expect(rule.matchTarget, MatchTarget.titleOnly);
      expect(rule.enabled, isTrue);
    });

    test('matches title only', () {
      final rule = LiveKeywordRule(
        id: 'test_id',
        mid: 12345678,
        upName: 'Test UP',
        keyword: '演唱会',
        matchTargetIndex: MatchTarget.titleOnly.index,
        enabled: true,
        createdAt: 1234567890,
      );

      expect(rule.matches(streamTitle: '今晚有演唱会', areaName: '娱乐'), isTrue);
      expect(rule.matches(streamTitle: '日常直播', areaName: '演唱会'), isFalse);
      expect(rule.matches(streamTitle: '日常直播', areaName: '娱乐'), isFalse);
    });

    test('matches area only', () {
      final rule = LiveKeywordRule(
        id: 'test_id',
        mid: 12345678,
        upName: 'Test UP',
        keyword: '演唱会',
        matchTargetIndex: MatchTarget.areaOnly.index,
        enabled: true,
        createdAt: 1234567890,
      );

      expect(rule.matches(streamTitle: '今晚有演唱会', areaName: '娱乐'), isFalse);
      expect(rule.matches(streamTitle: '日常直播', areaName: '演唱会'), isTrue);
    });

    test('matches both title and area', () {
      final rule = LiveKeywordRule(
        id: 'test_id',
        mid: 12345678,
        upName: 'Test UP',
        keyword: '演唱会',
        matchTargetIndex: MatchTarget.both.index,
        enabled: true,
        createdAt: 1234567890,
      );

      expect(rule.matches(streamTitle: '今晚有演唱会', areaName: '娱乐'), isTrue);
      expect(rule.matches(streamTitle: '日常直播', areaName: '演唱会'), isTrue);
      expect(rule.matches(streamTitle: '日常直播', areaName: '娱乐'), isFalse);
    });

    test('disabled rule does not match', () {
      final rule = LiveKeywordRule(
        id: 'test_id',
        mid: 12345678,
        upName: 'Test UP',
        keyword: '演唱会',
        matchTargetIndex: MatchTarget.titleOnly.index,
        enabled: false,
        createdAt: 1234567890,
      );

      expect(rule.matches(streamTitle: '今晚有演唱会', areaName: '娱乐'), isFalse);
    });

    test('copyWith creates new instance with updated values', () {
      final rule = LiveKeywordRule(
        id: 'test_id',
        mid: 12345678,
        upName: 'Test UP',
        keyword: '演唱会',
        matchTargetIndex: MatchTarget.titleOnly.index,
        enabled: true,
        createdAt: 1234567890,
      );

      final updated = rule.copyWith(enabled: false);

      expect(updated.enabled, isFalse);
      expect(updated.id, rule.id);
      expect(updated.keyword, rule.keyword);
    });

    test('serializes to JSON', () {
      final rule = LiveKeywordRule(
        id: 'test_id',
        mid: 12345678,
        upName: 'Test UP',
        keyword: '演唱会',
        matchTargetIndex: MatchTarget.titleOnly.index,
        enabled: true,
        createdAt: 1234567890,
      );

      final json = rule.toJson();
      expect(json['id'], 'test_id');
      expect(json['mid'], 12345678);
      expect(json['keyword'], '演唱会');
      expect(json['matchTarget'], 'titleOnly');
    });

    test('deserializes from JSON', () {
      final json = {
        'id': 'test_id',
        'mid': 12345678,
        'upName': 'Test UP',
        'keyword': '演唱会',
        'matchTarget': 'titleOnly',
        'enabled': true,
        'createdAt': 1234567890,
        'lastNotifiedAt': 0,
      };

      final rule = LiveKeywordRule.fromJson(json);
      expect(rule.id, 'test_id');
      expect(rule.mid, 12345678);
      expect(rule.keyword, '演唱会');
      expect(rule.matchTarget, MatchTarget.titleOnly);
    });

    test('keyword matching is case insensitive', () {
      final rule = LiveKeywordRule(
        id: 'test_id',
        mid: 12345678,
        upName: 'Test UP',
        keyword: 'CONCERT',
        matchTargetIndex: MatchTarget.titleOnly.index,
        enabled: true,
        createdAt: 1234567890,
      );

      expect(rule.matches(streamTitle: '今晚有演唱会', areaName: '娱乐'), isTrue);
      expect(rule.matches(streamTitle: 'CONCERT tonight', areaName: 'entertainment'), isTrue);
    });
  });
}
