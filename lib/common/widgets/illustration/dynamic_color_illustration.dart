import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Undraw-inspired empty-state heroes whose fills track [ColorScheme].
///
/// Pattern mirrors Seal's `DynamicColorImageVectors`: theme-bound accent fills
/// plus fixed neutral skin/ink tones so light/dark and dynamic color swap
/// without asset variants.
enum DynamicColorIllustrationType {
  /// Generic list / no-data empty.
  empty,

  /// Offline cache / download empty.
  download,

  /// Sync / streaming-style empty.
  sync,
}

/// Reusable Material dynamic-color illustration for empty states.
class DynamicColorIllustration extends StatelessWidget {
  const DynamicColorIllustration({
    super.key,
    this.type = DynamicColorIllustrationType.empty,
    this.height = 200,
    this.width,
  });

  final DynamicColorIllustrationType type;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = DynamicColorIllustrationPalette.fromScheme(scheme);
    return Semantics(
      label: '空状态插画',
      child: SizedBox(
        height: height,
        width: width ?? height * 1.15,
        child: CustomPaint(
          painter: _DynamicColorIllustrationPainter(
            type: type,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

/// Theme-derived roles used by undraw-like painters.
///
/// Uses Material 3 fixed / surface-container roles when available so dynamic
/// color and seed themes recolor the illustration without asset variants.
@immutable
class DynamicColorIllustrationPalette {
  const DynamicColorIllustrationPalette({
    required this.surface,
    required this.surfaceContainerHigh,
    required this.primary,
    required this.primaryContainer,
    required this.primaryFixedDim,
    required this.onPrimaryFixedVariant,
    required this.secondaryContainer,
    required this.tertiaryContainer,
    required this.outline,
    required this.ink,
    required this.skin,
  });

  factory DynamicColorIllustrationPalette.fromScheme(ColorScheme scheme) {
    return DynamicColorIllustrationPalette(
      surface: scheme.surface,
      surfaceContainerHigh: scheme.surfaceContainerHigh,
      primary: scheme.primary,
      primaryContainer: scheme.primaryContainer,
      primaryFixedDim: scheme.primaryFixedDim,
      onPrimaryFixedVariant: scheme.onPrimaryFixedVariant,
      secondaryContainer: scheme.secondaryContainer,
      tertiaryContainer: scheme.tertiaryContainer,
      outline: scheme.outlineVariant,
      // Undraw neutrals retained (same convention as Seal vectors).
      ink: const Color(0xFF3F3D56),
      skin: const Color(0xFF9F616A),
    );
  }

  final Color surface;
  final Color surfaceContainerHigh;
  final Color primary;
  final Color primaryContainer;
  final Color primaryFixedDim;
  final Color onPrimaryFixedVariant;
  final Color secondaryContainer;
  final Color tertiaryContainer;
  final Color outline;
  final Color ink;
  final Color skin;

  @override
  bool operator ==(Object other) {
    return other is DynamicColorIllustrationPalette &&
        other.surface == surface &&
        other.surfaceContainerHigh == surfaceContainerHigh &&
        other.primary == primary &&
        other.primaryContainer == primaryContainer &&
        other.primaryFixedDim == primaryFixedDim &&
        other.onPrimaryFixedVariant == onPrimaryFixedVariant &&
        other.secondaryContainer == secondaryContainer &&
        other.tertiaryContainer == tertiaryContainer &&
        other.outline == outline &&
        other.ink == ink &&
        other.skin == skin;
  }

  @override
  int get hashCode => Object.hash(
    surface,
    surfaceContainerHigh,
    primary,
    primaryContainer,
    primaryFixedDim,
    onPrimaryFixedVariant,
    secondaryContainer,
    tertiaryContainer,
    outline,
    ink,
    skin,
  );
}

class _DynamicColorIllustrationPainter extends CustomPainter {
  _DynamicColorIllustrationPainter({
    required this.type,
    required this.colors,
  });

  final DynamicColorIllustrationType type;
  final DynamicColorIllustrationPalette colors;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 240;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(scale);

    // Soft ground shadow (undraw floor strip).
    final ground = Paint()
      ..color = colors.surfaceContainerHigh.withValues(alpha: 0.9);
    final outlineGround = Paint()
      ..color = colors.outline.withValues(alpha: 0.35);
    canvas
      ..drawOval(
        Rect.fromCenter(center: const Offset(0, 92), width: 210, height: 28),
        ground,
      )
      ..drawOval(
        Rect.fromCenter(center: const Offset(0, 100), width: 170, height: 16),
        outlineGround,
      );

    switch (type) {
      case DynamicColorIllustrationType.download:
        _paintDownload(canvas);
      case DynamicColorIllustrationType.sync:
        _paintSync(canvas);
      case DynamicColorIllustrationType.empty:
        _paintEmpty(canvas);
    }
    canvas.restore();
  }

  void _paintEmpty(Canvas canvas) {
    // Floating card stack.
    final card = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(-18, 10), width: 110, height: 130),
      const Radius.circular(14),
    );
    final backCardPaint = Paint()
      ..color = colors.secondaryContainer.withValues(alpha: 0.85);
    final surfacePaint = Paint()..color = colors.surface;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colors.ink.withValues(alpha: 0.85);
    final headerPaint = Paint()..color = colors.primaryFixedDim;
    final linePaint = Paint()..color = colors.outline.withValues(alpha: 0.7);
    final plantPaint = Paint()..color = colors.tertiaryContainer;
    final potPaint = Paint()..color = colors.ink.withValues(alpha: 0.7);

    canvas
      ..drawRRect(card.shift(const Offset(14, 8)), backCardPaint)
      ..drawRRect(card, surfacePaint)
      ..drawRRect(card, strokePaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(card.left + 12, card.top + 16, card.width - 24, 18),
          const Radius.circular(6),
        ),
        headerPaint,
      );

    // Content lines.
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            card.left + 12,
            card.top + 48 + i * 18,
            card.width - 24 - i * 12,
            10,
          ),
          const Radius.circular(5),
        ),
        linePaint,
      );
    }

    // Person silhouette (simplified undraw figure).
    _paintPerson(
      canvas,
      origin: const Offset(58, 18),
      body: colors.primary,
      accent: colors.primaryContainer,
    );

    // Decorative plant blob.
    canvas
      ..drawCircle(const Offset(-78, 70), 18, plantPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-86, 78, 16, 28),
          const Radius.circular(4),
        ),
        potPaint,
      );
  }

  void _paintDownload(Canvas canvas) {
    // Device / phone body.
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(-36, 8), width: 92, height: 148),
      const Radius.circular(16),
    );
    final inkPaint = Paint()..color = colors.ink;
    final surfacePaint = Paint()..color = colors.surface;
    final badgePaint = Paint()..color = colors.primaryFixedDim;
    final arrowPaint = Paint()
      ..color = colors.onPrimaryFixedVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final chipSecondary = Paint()..color = colors.secondaryContainer;
    final chipPrimary = Paint()..color = colors.primaryContainer;
    final chipTertiary = Paint()..color = colors.tertiaryContainer;

    canvas
      ..drawRRect(phone, inkPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(-36, 4), width: 78, height: 124),
          const Radius.circular(10),
        ),
        surfacePaint,
      )
      ..drawCircle(const Offset(-36, 0), 28, badgePaint);

    // Arrow down.
    final arrow = Path()
      ..moveTo(-36, -14)
      ..lineTo(-36, 8)
      ..moveTo(-48, -2)
      ..lineTo(-36, 12)
      ..lineTo(-24, -2);
    canvas
      ..drawPath(arrow, arrowPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(18, -60, 56, 40),
          const Radius.circular(8),
        ),
        chipSecondary,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(32, -28, 64, 44),
          const Radius.circular(8),
        ),
        chipPrimary,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(24, 12, 52, 36),
          const Radius.circular(8),
        ),
        chipTertiary,
      );

    _paintPerson(
      canvas,
      origin: const Offset(70, 28),
      body: colors.primary,
      accent: colors.primaryContainer,
      scale: 0.9,
    );
  }

  void _paintSync(Canvas canvas) {
    // Cloud body.
    final cloudPaint = Paint()..color = colors.primaryContainer;
    final fixedPaint = Paint()..color = colors.primaryFixedDim;
    final inkPaint = Paint()..color = colors.ink;
    final surfacePaint = Paint()..color = colors.surface;
    final ring = Paint()
      ..color = colors.primaryFixedDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawCircle(const Offset(-24, -8), 36, cloudPaint)
      ..drawCircle(const Offset(18, -4), 30, cloudPaint)
      ..drawCircle(const Offset(-2, -28), 28, cloudPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-52, -12, 90, 42),
          const Radius.circular(20),
        ),
        cloudPaint,
      )
      ..drawArc(
        Rect.fromCenter(center: const Offset(-6, -6), width: 54, height: 54),
        -math.pi * 0.15,
        math.pi * 1.2,
        false,
        ring,
      );

    // Arrow heads.
    final head = Path()
      ..moveTo(14, -22)
      ..lineTo(22, -10)
      ..lineTo(6, -8);
    canvas
      ..drawPath(head, fixedPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-40, 42, 70, 48),
          const Radius.circular(10),
        ),
        inkPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-34, 48, 58, 32),
          const Radius.circular(6),
        ),
        surfacePaint,
      );

    _paintPerson(
      canvas,
      origin: const Offset(62, 20),
      body: colors.secondaryContainer,
      accent: colors.primary,
      scale: 0.95,
    );
  }

  void _paintPerson(
    Canvas canvas, {
    required Offset origin,
    required Color body,
    required Color accent,
    double scale = 1,
  }) {
    final skinPaint = Paint()..color = colors.skin;
    final hairPaint = Paint()..color = colors.ink.withValues(alpha: 0.9);
    final bodyPaint = Paint()..color = body;
    final inkPaint = Paint()..color = colors.ink;
    final accentPaint = Paint()..color = accent;

    canvas
      ..save()
      ..translate(origin.dx, origin.dy)
      ..scale(scale)
      ..drawCircle(const Offset(0, -46), 14, skinPaint)
      ..drawCircle(const Offset(0, -54), 12, hairPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-16, -30, 32, 48),
          const Radius.circular(12),
        ),
        bodyPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-14, 14, 12, 34),
          const Radius.circular(6),
        ),
        inkPaint,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(2, 14, 12, 34),
          const Radius.circular(6),
        ),
        inkPaint,
      )
      ..drawCircle(const Offset(-20, -10), 8, accentPaint)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _DynamicColorIllustrationPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.colors != colors;
  }
}
