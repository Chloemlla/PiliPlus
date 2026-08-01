import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/danmaku/danmaku_highlight_rule.dart';
import 'package:pili_plus/services/danmaku_highlight_service.dart';

void main() {
  group('DanmakuHighlightService matching', () {
    test('matches plain keywords case-insensitively as substrings', () {
      final store = _MemoryRuleStore()
        ..value = [_rule(id: 'plain', keyword: 'Host').toJson()];
      final service = _createService(store);

      expect(service.getMatchingRule('say hOsT now')?.id, 'plain');
    });

    test('matches regex rules case-insensitively', () {
      final store = _MemoryRuleStore()
        ..value = [
          _rule(
            id: 'regex',
            keyword: r'^foo\d+$',
            isRegex: true,
          ).toJson(),
        ];
      final service = _createService(store);

      expect(service.getMatchingRule('FOO42')?.id, 'regex');
    });

    test('returns the highest-priority matching rule', () {
      final store = _MemoryRuleStore()
        ..value = [
          _rule(id: 'plain', keyword: 'alert', priority: 1).toJson(),
          _rule(
            id: 'regex',
            keyword: r'^.*alert.*$',
            isRegex: true,
            priority: 9,
          ).toJson(),
        ];
      final service = _createService(store);

      expect(service.getMatchingRule('ALERT')?.id, 'regex');
    });

    test('ignores disabled and invalid regex rules', () {
      final store = _MemoryRuleStore()
        ..value = [
          _rule(
            id: 'disabled',
            keyword: 'match',
            priority: 20,
            enabled: false,
          ).toJson(),
          _rule(
            id: 'invalid',
            keyword: '[',
            isRegex: true,
            priority: 10,
          ).toJson(),
          _rule(id: 'valid', keyword: 'match').toJson(),
        ];
      final service = _createService(store);

      expect(service.getMatchingRule('MATCH')?.id, 'valid');
    });
  });

  group('DanmakuHighlightService persistence', () {
    test('persists add, edit, toggle, and delete operations', () async {
      final store = _MemoryRuleStore();
      final service = _createService(store);

      expect(
        await service.addRule(_rule(id: 'rule', keyword: '  主播  ')),
        isTrue,
      );
      expect(service.rules.single.keyword, '主播');
      expect(_persistedRules(store).single['keyword'], '主播');

      expect(
        await service.updateRule(
          _rule(id: 'rule', keyword: '谢谢', priority: 5),
        ),
        isTrue,
      );
      expect(_persistedRules(store).single['priority'], 5);

      await service.toggleRule('rule');
      expect(_persistedRules(store).single['enabled'], isFalse);

      await service.deleteRule('rule');
      expect(service.rules, isEmpty);
      expect(_persistedRules(store), isEmpty);
      expect(store.writeCount, 4);
    });

    test('caps loaded and newly added rules at 50', () async {
      final store = _MemoryRuleStore()
        ..value = List.generate(
          52,
          (index) => _rule(
            id: 'rule-$index',
            keyword: 'keyword-$index',
            priority: index,
          ).toJson(),
        );
      final service = _createService(store);

      expect(service.rules, hasLength(DanmakuHighlightService.maxRules));
      expect(service.rules.first.priority, 51);
      expect(
        await service.addRule(_rule(id: 'overflow', keyword: 'overflow')),
        isFalse,
      );
      expect(store.writeCount, 0);
    });

    test('rejects duplicate plain keywords case-insensitively', () async {
      final store = _MemoryRuleStore();
      final service = _createService(store);

      expect(
        await service.addRule(_rule(id: 'first', keyword: 'Host')),
        isTrue,
      );
      expect(
        await service.addRule(_rule(id: 'second', keyword: ' host ')),
        isFalse,
      );
      expect(service.rules, hasLength(1));
    });
  });
}

DanmakuHighlightService _createService(_MemoryRuleStore store) {
  final service = DanmakuHighlightService(
    readRules: () => store.value,
    writeRules: store.write,
  )..onInit();
  return service;
}

DanmakuHighlightRule _rule({
  required String id,
  required String keyword,
  bool isRegex = false,
  int priority = 0,
  bool enabled = true,
}) {
  return DanmakuHighlightRule(
    id: id,
    keyword: keyword,
    isRegex: isRegex,
    priority: priority,
    enabled: enabled,
    createdAt: DateTime.utc(2026, 7, 31),
  );
}

List<dynamic> _persistedRules(_MemoryRuleStore store) =>
    store.value! as List<dynamic>;

final class _MemoryRuleStore {
  Object? value;
  int writeCount = 0;

  Future<void> write(List<Map<String, dynamic>> data) async {
    value = data.map(Map<String, dynamic>.of).toList();
    writeCount++;
  }
}
