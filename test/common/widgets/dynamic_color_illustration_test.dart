import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pili_plus/common/widgets/illustration/dynamic_color_illustration.dart';
import 'package:pili_plus/common/widgets/loading_widget/http_error.dart';

void main() {
  testWidgets('DynamicColorIllustration paints for each type', (tester) async {
    for (final type in DynamicColorIllustrationType.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          home: Scaffold(
            body: Center(
              child: DynamicColorIllustration(type: type, height: 160),
            ),
          ),
        ),
      );
      expect(find.byType(DynamicColorIllustration), findsOneWidget);
      await tester.pump();
    }
  });

  test('palette tracks ColorScheme primary roles', () {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.light,
    );
    final palette = DynamicColorIllustrationPalette.fromScheme(scheme);
    expect(palette.primary, scheme.primary);
    expect(palette.primaryContainer, scheme.primaryContainer);
    expect(palette.primaryFixedDim, scheme.primaryFixedDim);
    expect(palette.onPrimaryFixedVariant, scheme.onPrimaryFixedVariant);
    expect(palette.surfaceContainerHigh, scheme.surfaceContainerHigh);
    expect(palette.skin, const Color(0xFF9F616A));
    expect(palette.ink, const Color(0xFF3F3D56));
  });

  testWidgets('HttpError uses download illustration when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              HttpError(
                errMsg: '暂无离线缓存',
                illustration: DynamicColorIllustrationType.download,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('暂无离线缓存'), findsOneWidget);
    expect(find.byType(DynamicColorIllustration), findsOneWidget);
  });
}
