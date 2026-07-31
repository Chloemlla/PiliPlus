import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/danmaku/danmaku_highlight_rule.dart';

void main() {
  group('HighlightColor', () {
    test('should have correct color values', () {
      expect(HighlightColor.red.value, const Color(0xFFFF4444));
      expect(HighlightColor.orange.value, const Color(0xFFFF8800));
      expect(HighlightColor.yellow.value, const Color(0xFFFFFF00));
      expect(HighlightColor.green.value, const Color(0xFF44FF44));
      expect(HighlightColor.blue.value, const Color(0xFF4488FF));
      expect(HighlightColor.purple.value, const Color(0xFFAA44FF));
      expect(HighlightColor.pink.value, const Color(0xFFFF44AA));
      expect(HighlightColor.white.value, const Color(0xFFFFFFFF));
    });

    test('should have Chinese labels', () {
      expect(HighlightColor.red.label, '红色');
      expect(HighlightColor.orange.label, '橙色');
      expect(HighlightColor.yellow.label, '黄色');
      expect(HighlightColor.green.label, '绿色');
      expect(HighlightColor.blue.label, '蓝色');
      expect(HighlightColor.purple.label, '紫色');
      expect(HighlightColor.pink.label, '粉色');
      expect(HighlightColor.white.label, '白色');
    });
  });

  group('DanmakuHighlightRule', () {
    test('should create rule with all fields', () {
      final now = DateTime.now();
      final rule = DanmakuHighlightRule(
        id: 'rule_1',
        keyword: '主播',
        isRegex: false,
        color: HighlightColor.yellow,
        priority: 1,
        enabled: true,
        createdAt: now,
      );

      expect(rule.id, 'rule_1');
      expect(rule.keyword, '主播');
      expect(rule.isRegex, false);
      expect(rule.color, HighlightColor.yellow);
      expect(rule.priority, 1);
      expect(rule.enabled, true);
      expect(rule.createdAt, now);
    });

    test('should use default values for optional fields', () {
      final now = DateTime.now();
      final rule = DanmakuHighlightRule(
        id: 'rule_1',
        keyword: '测试',
        createdAt: now,
      );

      expect(rule.isRegex, false);
      expect(rule.color, HighlightColor.yellow);
      expect(rule.priority, 0);
      expect(rule.enabled, true);
    });

    test('should convert to JSON and back', () {
      final now = DateTime.now();
      final rule = DanmakuHighlightRule(
        id: 'rule_1',
        keyword: '主播',
        isRegex: true,
        color: HighlightColor.red,
        priority: 5,
        enabled: false,
        createdAt: now,
      );

      final json = rule.toJson();
      final restored = DanmakuHighlightRule.fromJson(json);

      expect(restored.id, rule.id);
      expect(restored.keyword, rule.keyword);
      expect(restored.isRegex, rule.isRegex);
      expect(restored.color, rule.color);
      expect(restored.priority, rule.priority);
      expect(restored.enabled, rule.enabled);
      expect(restored.createdAt, rule.createdAt);
    });

    test('should handle missing optional fields in JSON', () {
      final json = {
        'id': 'rule_1',
        'keyword': '测试',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final rule = DanmakuHighlightRule.fromJson(json);

      expect(rule.id, 'rule_1');
      expect(rule.keyword, '测试');
      expect(rule.isRegex, false);
      expect(rule.color, HighlightColor.yellow);
      expect(rule.priority, 0);
      expect(rule.enabled, true);
    });

    test('should copyWith create new instance with updated fields', () {
      final now = DateTime.now();
      final original = DanmakuHighlightRule(
        id: 'rule_1',
        keyword: '原始',
        isRegex: false,
        color: HighlightColor.yellow,
        priority: 0,
        enabled: true,
        createdAt: now,
      );

      final copied = original.copyWith(
        keyword: '更新',
        color: HighlightColor.red,
        enabled: false,
      );

      expect(copied.id, original.id);
      expect(copied.keyword, '更新');
      expect(copied.color, HighlightColor.red);
      expect(copied.enabled, false);
      expect(original.keyword, '原始');
      expect(original.color, HighlightColor.yellow);
      expect(original.enabled, true);
    });

    test('should compare rules by id', () {
      final now = DateTime.now();
      final rule1 = DanmakuHighlightRule(
        id: 'rule_1',
        keyword: '关键词1',
        createdAt: now,
      );
      final rule2 = DanmakuHighlightRule(
        id: 'rule_1',
        keyword: '关键词2',
        createdAt: now,
      );
      final rule3 = DanmakuHighlightRule(
        id: 'rule_2',
        keyword: '关键词1',
        createdAt: now,
      );

      expect(rule1 == rule2, true);
      expect(rule1 == rule3, false);
      expect(rule1.hashCode, rule2.hashCode);
    });
  });

  group('DanmakuQuickRule', () {
    test('should create quick rule with all fields', () {
      const quick = DanmakuQuickRule(
        keyword: '主播',
        color: HighlightColor.yellow,
      );

      expect(quick.keyword, '主播');
      expect(quick.color, HighlightColor.yellow);
    });
  });

  group('danmakuQuickRules', () {
    test('should contain expected quick rules', () {
      expect(danmakuQuickRules.length, 4);

      expect(danmakuQuickRules[0].keyword, '主播');
      expect(danmakuQuickRules[0].color, HighlightColor.yellow);

      expect(danmakuQuickRules[1].keyword, '谢谢');
      expect(danmakuQuickRules[1].color, HighlightColor.green);

      expect(danmakuQuickRules[2].keyword, '厉害');
      expect(danmakuQuickRules[2].color, HighlightColor.orange);

      expect(danmakuQuickRules[3].keyword, '注意');
      expect(danmakuQuickRules[3].color, HighlightColor.red);
    });
  });
}
