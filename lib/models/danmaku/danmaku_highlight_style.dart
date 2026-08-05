import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;

/// Resolved colors passed to the danmaku renderer for one content item.
@immutable
final class DanmakuHighlightStyle {
  const DanmakuHighlightStyle({
    required this.fillColor,
    this.strokeColor,
  });

  final Color fillColor;
  final Color? strokeColor;

  /// Keeps existing colored fills and uses the rule color as their outline.
  static DanmakuHighlightStyle resolve({
    required Color displayedColor,
    Color? highlightColor,
  }) {
    if (highlightColor == null) {
      return DanmakuHighlightStyle(fillColor: displayedColor);
    }

    if (displayedColor.toARGB32() == _white.toARGB32()) {
      return DanmakuHighlightStyle(fillColor: highlightColor);
    }

    return DanmakuHighlightStyle(
      fillColor: displayedColor,
      strokeColor: highlightColor,
    );
  }

  static const _white = Color(0xFFFFFFFF);
}
