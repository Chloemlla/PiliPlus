import 'package:flutter/material.dart';

/// One-shot fluorescent highlight around a settings row after search locate.
class SettingsHighlightFlash extends StatefulWidget {
  const SettingsHighlightFlash({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<SettingsHighlightFlash> createState() => _SettingsHighlightFlashState();
}

class _SettingsHighlightFlashState extends State<SettingsHighlightFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0, end: 1).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1),
        weight: 1.2,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1, end: 0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 2,
      ),
    ]).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Fluorescent flash: bright primary/tertiary blend that remains readable.
    final flashColor = Color.alphaBlend(
      scheme.tertiary.withValues(alpha: 0.55),
      scheme.primaryContainer.withValues(alpha: 0.85),
    );

    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        final t = _opacity.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: t <= 0 ? null : flashColor.withValues(alpha: 0.55 * t),
            border: t <= 0
                ? null
                : Border.all(
                    color: scheme.tertiary.withValues(alpha: 0.85 * t),
                    width: 1.5,
                  ),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}