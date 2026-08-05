import 'package:pili_plus/common/assets.dart';
import 'package:pili_plus/pages/onboarding/oss_notice_data.dart';
import 'package:pili_plus/utils/extension/num_ext.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:pili_plus/utils/utils.dart';
import 'package:flutter/material.dart';

class OssNoticePage extends StatefulWidget {
  const OssNoticePage({
    super.key,
    this.markSeenOnClose = true,
    this.onFinished,
  });

  final bool markSeenOnClose;
  final Future<void> Function()? onFinished;

  @override
  State<OssNoticePage> createState() => _OssNoticePageState();
}

class _OssNoticePageState extends State<OssNoticePage> {
  bool _closing = false;

  Future<void> _completeAndClose() async {
    if (_closing) return;
    _closing = true;
    try {
      await widget.onFinished?.call();
    } finally {
      if (mounted) {
        // Force-pop: first-launch uses PopScope(canPop: false), so maybePop is a no-op.
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Material PopScope binds to this MaterialPageRoute, unlike the Get-route
    // helper used by in-app pages.
    return PopScope(
      canPop: !widget.markSeenOnClose,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !widget.markSeenOnClose) return;
        _completeAndClose();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  children: [
                    Center(
                      child: Image.asset(
                        Assets.logo,
                        width: 88,
                        height: 88,
                        excludeFromSemantics: true,
                        cacheWidth: 88.cacheSize(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '开源声明与第三方鸣谢',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      OssNoticeData.projectName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionCard(
                      icon: Icons.code,
                      title: '官方开源地址',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            OssNoticeData.sourceUrl,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => PageUtils.launchURL(
                                  OssNoticeData.sourceUrl,
                                ),
                                icon: const Icon(Icons.open_in_new, size: 18),
                                label: const Text('打开仓库'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => Utils.copyText(
                                  OssNoticeData.sourceUrl,
                                  toastText: '已复制开源地址',
                                ),
                                icon: const Icon(Icons.copy, size: 18),
                                label: const Text('复制链接'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.verified_user_outlined,
                      title: OssNoticeData.freeNoticeTitle,
                      accent: colorScheme.error,
                      child: Text(
                        OssNoticeData.freeNoticeBody,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      icon: Icons.gavel_outlined,
                      title: '本项目开源协议',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            OssNoticeData.projectLicense,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '完整协议文本见仓库 LICENSE 文件。使用、修改与再分发须遵守 GPL-3.0。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => PageUtils.launchURL(
                              OssNoticeData.projectLicenseUrl,
                            ),
                            icon: const Icon(Icons.description_outlined, size: 18),
                            label: const Text('查看 LICENSE'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            OssNoticeData.disclaimer,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '第三方依赖鸣谢',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '下列为项目直接依赖、关键 fork 与谱系上游的精选清单（名称 / 作者 / 描述 / 协议），'
                      '不是完整传递依赖树。点击条目可打开对应开源地址。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...OssNoticeData.credits.map(
                      (credit) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CreditTile(credit: credit),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _completeAndClose,
                    child: Text(
                      widget.markSeenOnClose ? '我已了解，继续' : '关闭',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.accent,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = accent ?? colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.credit});

  final OssCredit credit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canOpen = credit.url != null && credit.url!.isNotEmpty;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canOpen ? () => PageUtils.launchURL(credit.url!) : null,
        onLongPress: canOpen
            ? () => Utils.copyText(credit.url!, toastText: '已复制链接')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      credit.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canOpen)
                    Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: colorScheme.outline,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '作者：${credit.author}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                credit.description,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '协议：${credit.license}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
