import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/utils/clash_compat.dart';

void main() {
  group('ClashCompat.describeDeniedReason', () {
    test('每个 CMFA 取值都给出可操作的做法', () {
      const reasons = <String>[
        'pending_user_approval',
        'denied_by_user',
        'signer_unverified',
        'not_partner',
        'no_signature',
      ];
      final described = reasons
          .map(ClashCompat.describeDeniedReason)
          .toList(growable: false);

      // 拼错任何一个 key 都会退到 “Clash 返回原因：” 分支，这里正是要卡住那种情况。
      for (final text in described) {
        expect(text, isNot(contains('Clash 返回原因')));
        expect(text, isNotEmpty);
      }
      expect(described.toSet(), hasLength(reasons.length));
    });

    test('未知取值原样带出，缺原因时如实说明', () {
      expect(
        ClashCompat.describeDeniedReason('brand_new_reason'),
        contains('brand_new_reason'),
      );
      expect(ClashCompat.describeDeniedReason(null), 'Clash 未说明原因');
    });
  });
}
