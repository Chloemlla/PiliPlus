import 'package:pili_plus/common/assets.dart';
import 'package:pili_plus/common/constants.dart';
import 'package:pili_plus/common/widgets/flutter/pop_scope.dart';
import 'package:pili_plus/pages/onboarding/improvements_guide_data.dart';
import 'package:pili_plus/utils/extension/num_ext.dart';
import 'package:pili_plus/utils/page_utils.dart';
import 'package:flutter/material.dart' hide PopScope;

class ImprovementsGuidePage extends StatefulWidget {
  const ImprovementsGuidePage({
    super.key,
    this.markSeenOnClose = true,
    this.onFinished,
  });

  /// When true, calling skip/finish should mark first-launch guide as seen.
  final bool markSeenOnClose;

  /// Optional callback after user finishes or skips (before route pop).
  final Future<void> Function()? onFinished;

  @override
  State<ImprovementsGuidePage> createState() => _ImprovementsGuidePageState();
}

class _ImprovementsGuidePageState extends State<ImprovementsGuidePage> {
  final _controller = PageController();
  int _index = 0;
  bool _closing = false;

  List<ImprovementsGuidePageData> get _pages => ImprovementsGuideData.pages;

  bool get _isLast => _index >= _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

  void _goNext() {
    if (_isLast) {
      _completeAndClose();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final padding = MediaQuery.viewPaddingOf(context);

    return popScope(
      canPop: !widget.markSeenOnClose,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !widget.markSeenOnClose) return;
        _completeAndClose();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  8 + padding.left,
                  4,
                  8 + padding.right,
                  0,
                ),
                child: Row(
                  children: [
                    Text(
                      '${_index + 1} / ${_pages.length}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                    const Spacer(),
                    if (!_isLast)
                      TextButton(
                        onPressed: _completeAndClose,
                        child: const Text('跳过'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    return _GuideSlide(data: _pages[index], isFirst: index == 0);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20 + padding.left,
                  8,
                  20 + padding.right,
                  16 + padding.bottom,
                ),
                child: Column(
                  children: [
                    _PageDots(
                      count: _pages.length,
                      index: _index,
                      color: colorScheme.primary,
                      inactive: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_index > 0)
                          OutlinedButton(
                            onPressed: () {
                              _controller.previousPage(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            child: const Text('上一页'),
                          )
                        else
                          const SizedBox(width: 88),
                        const Spacer(),
                        FilledButton(
                          onPressed: _goNext,
                          child: Text(_isLast ? '开始使用' : '下一步'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideSlide extends StatelessWidget {
  const _GuideSlide({required this.data, required this.isFirst});

  final ImprovementsGuidePageData data;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final padding = MediaQuery.viewPaddingOf(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        24 + padding.left,
        8,
        24 + padding.right,
        12,
      ),
      children: [
        if (isFirst) ...[
          Center(
            child: Image.asset(
              Assets.logo,
              width: 96,
              height: 96,
              excludeFromSemantics: true,
              cacheWidth: 96.cacheSize(context),
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                data.icon,
                size: 36,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (data.platformHint != null) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                data.platformHint!,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          data.subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        ...data.bullets.map(
          (bullet) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    bullet,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (data.tip != null) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.tip!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isFirst) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => PageUtils.launchURL(Constants.sourceCodeUrl),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('查看源码仓库'),
          ),
        ],
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.color,
    required this.inactive,
  });

  final int count;
  final int index;
  final Color color;
  final Color inactive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final selected = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: selected ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: selected ? color : inactive,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
