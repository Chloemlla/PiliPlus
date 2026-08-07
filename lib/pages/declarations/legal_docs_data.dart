import 'package:flutter/material.dart';

class LegalDocItem {
  const LegalDocItem({
    required this.key,
    required this.title,
    required this.url,
    this.icon,
  });

  /// Stable identifier; keep unchanged so links and future logic can rely on it.
  final String key;
  final String title;
  final String url;
  final IconData? icon;
}

/// Legal-document menu for the "应用声明" section.
///
/// Each item opens [LegalDocItem.url] in the built-in webview. Default URLs
/// point to the markdown pages under `docs/legal/` in this repository, rendered
/// by GitHub. To host the texts elsewhere, replace the [url] values here — no
/// other change is needed.
abstract final class LegalDocsData {
  static const String _legalBase =
      'https://github.com/Chloemlla/PiliPlus/blob/main/docs/legal';

  static const List<LegalDocItem> items = [
    LegalDocItem(
      key: 'user-agreement',
      title: '用户协议',
      url: '$_legalBase/user-agreement.md',
      icon: Icons.description_outlined,
    ),
    LegalDocItem(
      key: 'privacy-policy',
      title: '隐私政策',
      url: '$_legalBase/privacy-policy.md',
      icon: Icons.privacy_tip_outlined,
    ),
    LegalDocItem(
      key: 'membership-agreement',
      title: '会员服务协议',
      url: '$_legalBase/membership-agreement.md',
      icon: Icons.workspace_premium_outlined,
    ),
    LegalDocItem(
      key: 'personal-info-collection-list',
      title: '个人信息收集清单',
      url: '$_legalBase/personal-info-collection-list.md',
      icon: Icons.list_alt_outlined,
    ),
    LegalDocItem(
      key: 'other',
      title: '其他',
      url: '$_legalBase/other.md',
      icon: Icons.more_horiz_outlined,
    ),
  ];
}
