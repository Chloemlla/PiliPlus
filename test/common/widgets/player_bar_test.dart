import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/common/widgets/player_bar.dart';

void main() {
  testWidgets('lays out unscaled children at their intrinsic widths', (
    tester,
  ) async {
    await tester.pumpWidget(_playerBar(width: 500));

    final bar = tester.renderObject<RenderBox>(find.byType(PlayerBar));
    final left = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey<String>('left')),
    );
    final right = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey<String>('right')),
    );

    expect(bar.size, const Size(500, 40));
    // The bar retains its tight height constraint when laying out children.
    expect(left.size, const Size(140, 40));
    expect(right.size, const Size(180, 40));
    expect(_relativePoint(left, bar, Offset.zero).dx, closeTo(0, 0.001));
    expect(_relativePoint(left, bar, Offset.zero).dy, closeTo(0, 0.001));
    final leftBottom = _relativePoint(
      left,
      bar,
      Offset(left.size.width, left.size.height),
    );
    expect(leftBottom.dx, closeTo(140, 0.001));
    expect(leftBottom.dy, closeTo(40, 0.001));
    final rightTop = _relativePoint(right, bar, Offset.zero);
    expect(rightTop.dx, closeTo(320, 0.001));
    expect(rightTop.dy, closeTo(0, 0.001));
    final rightBottom = _relativePoint(
      right,
      bar,
      Offset(right.size.width, right.size.height),
    );
    expect(rightBottom.dx, closeTo(500, 0.001));
    expect(rightBottom.dy, closeTo(40, 0.001));
  });

  testWidgets('uses intrinsic width when the parent width is unbounded', (
    tester,
  ) async {
    await tester.pumpWidget(_unboundedPlayerBar());

    final bar = tester.renderObject<RenderBox>(find.byType(PlayerBar));
    final left = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey<String>('left')),
    );
    final right = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey<String>('right')),
    );

    expect(bar.size, const Size(320, 40));
    expect(left.size, const Size(140, 40));
    expect(right.size, const Size(180, 40));
    expect(_relativePoint(left, bar, Offset.zero).dx, closeTo(0, 0.001));
    expect(_relativePoint(right, bar, Offset.zero).dx, closeTo(140, 0.001));
    expect(
      _relativePoint(
        right,
        bar,
        Offset(right.size.width, right.size.height),
      ).dx,
      closeTo(320, 0.001),
    );
  });

  test('requires exactly two children', () {
    expect(
      () => PlayerBar(children: [const SizedBox()]),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => PlayerBar(
        children: [
          const SizedBox(),
          const SizedBox(),
          const SizedBox(),
        ],
      ),
      throwsA(isA<AssertionError>()),
    );
  });

Widget _playerBar({required double width}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 40,
          child: PlayerBar(
            children: [
              const SizedBox(
                key: ValueKey<String>('left'),
                width: 140,
                height: 32,
              ),
              const SizedBox(
                key: ValueKey<String>('right'),
                width: 180,
                height: 32,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Offset _relativePoint(RenderBox child, RenderBox bar, Offset point) {
  return child.localToGlobal(point) - bar.localToGlobal(Offset.zero);
}
