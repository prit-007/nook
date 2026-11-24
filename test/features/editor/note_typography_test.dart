import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/theme/note_theme_scope.dart';

void main() {
  group('Step 6 — Per-note typography: Explicit NoteFontStyle', () {
    testWidgets(
        'NoteFontStyle.serif forces serif font regardless of cool seed color',
        (tester) async {
      late TextTheme result;
      // Cool blue seed
      const coolScheme = ColorScheme.light(primary: Color(0xFF1E88E5));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = NoteThemeScope.buildDynamicTextTheme(
                context,
                coolScheme,
                fontStyle: NoteFontStyle.serif,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result.displayLarge?.fontFamily, equals('Playfair Display'));
      expect(result.titleLarge?.fontFamily, equals('Playfair Display'));
    });

    testWidgets('NoteFontStyle.sans forces sans font even with warm seed color',
        (tester) async {
      late TextTheme result;
      // Warm terracotta seed
      const warmScheme = ColorScheme.light(primary: Color(0xFFD84315));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = NoteThemeScope.buildDynamicTextTheme(
                context,
                warmScheme,
                fontStyle: NoteFontStyle.sans,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
          result.displayLarge?.fontFamily, isNot(equals('Playfair Display')));
    });

    testWidgets('NoteFontStyle.mono forces monospace font', (tester) async {
      late TextTheme result;
      const neutralScheme = ColorScheme.light(primary: Color(0xFF6200EE));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = NoteThemeScope.buildDynamicTextTheme(
                context,
                neutralScheme,
                fontStyle: NoteFontStyle.mono,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result.bodyLarge?.fontFamily, equals('monospace'));
    });
  });
}
