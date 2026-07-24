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
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    // Soft ground shadow (undraw floor strip).
    final ground = Paint()
      ..color = colors.surfaceContainerHigh.withValues(alpha: 0.9);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 92), width: 210, height: 28),
      ground,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 100), width: 170, height: 16),
      Paint()..color = colors.outline.withValues(alpha: 0.35),
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
    canvas.drawRRect(
      card.shift(const Offset(14, 8)),
      Paint()..color = colors.secondaryContainer.withValues(alpha: 0.85),
    );
    canvas.drawRRect(card, Paint()..color = colors.surface);
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = colors.ink.withValues(alpha: 0.85),
    );

    // Accent header bar on card.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(card.left + 12, card.top + 16, card.width - 24, 18),
        const Radius.circular(6),
      ),
      Paint()..color = colors.primaryFixedDim,
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
        Paint()..color = colors.outline.withValues(alpha: 0.7),
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
    canvas.drawCircle(
      const Offset(-78, 70),
      18,
      Paint()..color = colors.tertiaryContainer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-86, 78, 16, 28),
        const Radius.circular(4),
      ),
      Paint()..color = colors.ink.withValues(alpha: 0.7),
    );
  }

  void _paintDownload(Canvas canvas) {
    // Device / phone body.
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(-36, 8), width: 92, height: 148),
      const Radius.circular(16),
    );
    canvas.drawRRect(phone, Paint()..color = colors.ink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-36, 4), width: 78, height: 124),
        const Radius.circular(10),
      ),
      Paint()..color = colors.surface,
    );

    // Download badge circle (primary fixed dim like Seal).
    canvas.drawCircle(
      const Offset(-36, 0),
      28,
      Paint()..color = colors.primaryFixedDim,
    );
    // Arrow down.
    final arrow = Path()
      ..moveTo(-36, -14)
      ..lineTo(-36, 8)
      ..moveTo(-48, -2)
      ..lineTo(-36, 12)
      ..lineTo(-24, -2);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = colors.onPrimaryFixedVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Floating file chips.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, -60, 56, 40),
        const Radius.circular(8),
      ),
      Paint()..color = colors.secondaryContainer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(32, -28, 64, 44),
        const Radius.circular(8),
      ),
      Paint()..color = colors.primaryContainer,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(24, 12, 52, 36),
        const Radius.circular(8),
      ),
      Paint()..color = colors.tertiaryContainer,
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
    canvas.drawCircle(const Offset(-24, -8), 36, cloudPaint);
    canvas.drawCircle(const Offset(18, -4), 30, cloudPaint);
    canvas.drawCircle(const Offset(-2, -28), 28, cloudPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-52, -12, 90, 42),
        const Radius.circular(20),
      ),
      cloudPaint,
    );

    // Sync arrows ring.
    final ring = Paint()
      ..color = colors.primaryFixedDim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
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
    canvas.drawPath(head, Paint()..color = colors.primaryFixedDim);

    // Ground device.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-40, 42, 70, 48),
        const Radius.circular(10),
      ),
      Paint()..color = colors.ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-34, 48, 58, 32),
        const Radius.circular(6),
      ),
      Paint()..color = colors.surface,
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
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);

    // Head.
    canvas.drawCircle(const Offset(0, -46), 14, Paint()..color = colors.skin);
    // Hair blob.
    canvas.drawCircle(
      const Offset(0, -54),
      12,
      Paint()..color = colors.ink.withValues(alpha: 0.9),
    );
    // Torso.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-16, -30, 32, 48),
        const Radius.circular(12),
      ),
      Paint()..color = body,
    );
    // Legs.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, 14, 12, 34),
        const Radius.circular(6),
      ),
      Paint()..color = colors.ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(2, 14, 12, 34),
        const Radius.circular(6),
      ),
      Paint()..color = colors.ink,
    );
    // Accent sleeve.
    canvas.drawCircle(const Offset(-20, -10), 8, Paint()..color = accent);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DynamicColorIllustrationPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.colors != colors;
  }
}
