import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/common/widgets/player_bar.dart';

const _barKey = Key('bar');
const _leadingKey = Key('leading');
const _trailingKey = Key('trailing');
const _firstTrailingKey = Key('first-trailing');
const _lastTrailingKey = Key('last-trailing');

void main() {
  testWidgets('constrains and scrolls trailing controls on narrow bars', (
    tester,
  ) async {
    await _pumpPlayerBar(tester, width: 240);

    expect(tester.takeException(), isNull);

    final barRect = tester.getRect(find.byKey(_barKey));
    final leadingRect = tester.getRect(find.byKey(_leadingKey));
    final trailingRect = tester.getRect(find.byKey(_trailingKey));
    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));
    final lastTrailingRect = tester.getRect(find.byKey(_lastTrailingKey));

    expect(leadingRect.width, 140);
    expect(leadingRect.left, barRect.left);
    expect(scrollRect.left, leadingRect.right);
    expect(scrollRect.right, barRect.right);
    expect(scrollRect.width, 100);
    expect(trailingRect.width, 180);
    expect(lastTrailingRect.right, scrollRect.right);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(PlayerBar),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, 80);

    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    final firstTrailingRect = tester.getRect(find.byKey(_firstTrailingKey));
    expect(firstTrailingRect.left, scrollRect.left);
  });

  testWidgets('right-aligns trailing controls on wide bars', (tester) async {
    await _pumpPlayerBar(tester, width: 500);

    expect(tester.takeException(), isNull);

    final barRect = tester.getRect(find.byKey(_barKey));
    final leadingRect = tester.getRect(find.byKey(_leadingKey));
    final trailingRect = tester.getRect(find.byKey(_trailingKey));
    final scrollRect = tester.getRect(find.byType(SingleChildScrollView));

    expect(leadingRect.width, 140);
    expect(leadingRect.left, barRect.left);
    expect(scrollRect.left, leadingRect.right);
    expect(scrollRect.right, barRect.right);
    expect(trailingRect.width, 180);
    expect(trailingRect.right, barRect.right);

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(PlayerBar),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, 0);
  });
}

Future<void> _pumpPlayerBar(
  WidgetTester tester, {
  required double width,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: _barKey,
            width: width,
            height: 40,
            child: PlayerBar(
              leading: const SizedBox(
                key: _leadingKey,
                width: 140,
                height: 32,
              ),
              trailing: const Row(
                key: _trailingKey,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    key: _firstTrailingKey,
                    width: 90,
                    height: 32,
                  ),
                  SizedBox(
                    key: _lastTrailingKey,
                    width: 90,
                    height: 32,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
