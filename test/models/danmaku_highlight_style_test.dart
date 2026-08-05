import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/models/danmaku/danmaku_highlight_style.dart';

void main() {
  group('DanmakuHighlightStyle.resolve', () {
    test('keeps the displayed color when no rule matches', () {
      const displayedColor = Color(0xFF4488FF);

      final style = DanmakuHighlightStyle.resolve(
        displayedColor: displayedColor,
      );

      expect(style.fillColor, displayedColor);
      expect(style.strokeColor, isNull);
    });

    test('replaces a white fill with the matching rule color', () {
      const highlightColor = Color(0xFFFFFF00);

      final style = DanmakuHighlightStyle.resolve(
        displayedColor: Colors.white,
        highlightColor: highlightColor,
      );

      expect(style.fillColor, highlightColor);
      expect(style.strokeColor, isNull);
    });

    test('keeps an existing colored fill and colors its outline', () {
      const displayedColor = Color(0xFF44FF44);
      const highlightColor = Color(0xFFFF4444);

      final style = DanmakuHighlightStyle.resolve(
        displayedColor: displayedColor,
        highlightColor: highlightColor,
      );

      expect(style.fillColor, displayedColor);
      expect(style.strokeColor, highlightColor);
    });

    test('allows blockColorful white output to use the rule fill', () {
      const blockedDisplayColor = Color(0xFFFFFFFF);
      const highlightColor = Color(0xFFAA44FF);

      final style = DanmakuHighlightStyle.resolve(
        displayedColor: blockedDisplayColor,
        highlightColor: highlightColor,
      );

      expect(style.fillColor, highlightColor);
      expect(style.strokeColor, isNull);
    });
  });
}
