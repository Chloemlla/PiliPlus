import 'package:pili_plus/common/widgets/dialog/dialog.dart';
import 'package:pili_plus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:pili_plus/common/widgets/view_safe_area.dart';
import 'package:pili_plus/services/privacy_consent_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

enum WithdrawConsentType { consent, privacyPolicy }

class WithdrawConsentPage extends StatefulWidget {
  const WithdrawConsentPage({
    super.key,
    this.type = WithdrawConsentType.consent,
  });

  final WithdrawConsentType type;

  @override
  State<WithdrawConsentPage> createState() => _WithdrawConsentPageState();
}

class _WithdrawConsentPageState extends State<WithdrawConsentPage> {
  late final WithdrawConsentType _type = Get.arguments is WithdrawConsentType
      ? Get.arguments as WithdrawConsentType
      : widget.type;

  late bool _agreed = PrivacyConsentService.hasAgreed;

  bool get _isPrivacy => _type == WithdrawConsentType.privacyPolicy;

  String get _title => _isPrivacy ? '撤回隐私政策同意' : '撤回同意';

  Future<void> _withdraw() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: const Text('确认撤回'),
      content: Text(
        _isPrivacy
            ? '撤回后，应用将不再视为你已同意《隐私政策》，相关同意标记将被清除。确定撤回？'
            : '撤回后，应用将不再视为你已同意相关条款，相关同意标记将被清除。确定撤回？',
      ),
    );
    if (!confirmed || !mounted) {
      return;
    }
    await PrivacyConsentService.withdrawAgreed();
    setState(() => _agreed = false);
    SmartDialog.showToast('已撤回，同意标记已清除');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SimpleScaffold(
      appBar: AppBar(title: Text(_title)),
      body: ViewSafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前状态',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _agreed
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 20,
                        color: _agreed
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _agreed ? '已同意（已授权）' : '未同意（未授权）',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isPrivacy
                  ? '你可以在任意时间撤回对《隐私政策》的同意。撤回后，应用将不再视为你已同意其隐私条款；'
                      '应用收集的个人信息仅用于实现 Bilibili 客户端功能（详见隐私政策），撤回不会影响已按你的明确操作完成的内容，但可能影响需要该授权才能提供的能力。'
                  : '你可以在任意时间撤回对相关条款的同意。撤回后，应用将不再视为你已同意相关条款；'
                      '这不会清除你本地保存的设置或登录信息，但会重置同意标记，应用后续如需再次征得同意时会重新提示。',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _agreed ? _withdraw : null,
                child: const Text('撤回同意'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '「撤回同意」仅清除本地的同意标记，不会从 Bilibili 删除你的账号或数据；如需注销 B 站账号，请在 B 站官方客户端或网页端操作。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
