import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/common/widgets/player_bar.dart';

void main() {
  testWidgets('renders children without error on narrow bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            child: SizedBox(
              width: 240,
              height: 40,
              child: const PlayerBar(
                children: [
                  SizedBox(width: 140, height: 32),
                  SizedBox(width: 180, height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders children without error on wide bar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            child: SizedBox(
              width: 500,
              height: 40,
              child: const PlayerBar(
                children: [
                  SizedBox(width: 140, height: 32),
                  SizedBox(width: 180, height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}