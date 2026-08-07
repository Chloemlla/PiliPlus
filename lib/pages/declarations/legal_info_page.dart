import 'package:pili_plus/common/widgets/flutter/list_tile.dart';
import 'package:pili_plus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:pili_plus/common/widgets/view_safe_area.dart';
import 'package:pili_plus/pages/declarations/legal_docs_data.dart';
import 'package:pili_plus/pages/declarations/withdraw_consent_page.dart';
import 'package:pili_plus/services/privacy_consent_service.dart';
import 'package:flutter/material.dart' hide ListTile;
import 'package:get/get.dart';

class LegalInfoPage extends StatelessWidget {
  const LegalInfoPage({super.key});

  void _openDoc(BuildContext context, LegalDocItem item) {
    // Viewing the privacy policy counts as acknowledging it, which is what the
    // withdraw-privacy-consent page later revokes.
    if (item.key == 'privacy-policy') {
      PrivacyConsentService.markAgreed();
    }
    Get.toNamed(
      '/webview',
      parameters: {'url': item.url},
      arguments: {'inApp': true},
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final arrow = Icon(Icons.arrow_forward, size: 16, color: outline);
    return SimpleScaffold(
      appBar: AppBar(title: const Text('法律信息')),
      body: ViewSafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ...LegalDocsData.items.map(
              (item) => ListTile(
                leading: Icon(
                  item.icon ?? Icons.description_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(item.title),
                trailing: arrow,
                onTap: () => _openDoc(context, item),
              ),
            ),
            Divider(
              thickness: 1,
              height: 24,
              color: theme.colorScheme.outlineVariant,
            ),
            ListTile(
              leading: const Icon(Icons.power_settings_new_outlined),
              title: const Text('撤回同意'),
              subtitle: Text(
                '查看当前授权状态并撤回同意',
                style: TextStyle(color: outline),
              ),
              trailing: arrow,
              onTap: () => Get.toNamed(
                '/withdrawConsent',
                arguments: WithdrawConsentType.consent,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('撤回隐私政策同意'),
              subtitle: Text(
                '查看隐私政策同意状态并撤回',
                style: TextStyle(color: outline),
              ),
              trailing: arrow,
              onTap: () => Get.toNamed(
                '/withdrawConsent',
                arguments: WithdrawConsentType.privacyPolicy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
