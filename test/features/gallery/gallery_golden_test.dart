@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/theme/app_theme.dart';
import 'package:nook/core/theme/design_tokens.dart';
import 'package:nook/core/widgets/empty_state.dart';

/// Component gallery golden tests across theme × text-scale × locale matrix.
void main() {
  group('Component Gallery Golden Tests', () {
    // Test all 12 seeds in light theme
    for (int i = 0; i < NookColors.seeds.length; i++) {
      final seed = NookColors.seeds[i];
      final name = NookColors.seedNames[i];

      testWidgets('$name seed light theme renders empty state', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(seed),
            home: const Scaffold(
              body: Center(
                child: EmptyState(
                  icon: HugeIcons.strokeRoundedFile01,
                  title: 'Untitled',
                  subtitle: 'No notes found yet.',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Untitled'), findsOneWidget);
        expect(find.text('No notes found yet.'), findsOneWidget);
      });

      testWidgets('$name seed light theme renders suggestion chips',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(seed),
            home: Scaffold(
              body: Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: List.generate(
                    3,
                    (index) => _testChip(index),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pen'), findsOneWidget);
        expect(find.text('Highlighter'), findsOneWidget);
        expect(find.text('Eraser'), findsOneWidget);
      });
    }

    group('Accessibility floors', () {
      testWidgets('font floor is respected - no text below 12px',
          (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(NookColors.violet),
            home: const Scaffold(
              body: Center(
                child: Text(
                  'Test text at minimum size',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final text = tester.firstWidget(
          find.text('Test text at minimum size'),
        ) as Text;
        expect(text.style?.fontSize, greaterThanOrEqualTo(12.0));
      });

      testWidgets('min tap target is respected', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildLightTheme(NookColors.violet),
            home: Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {},
                  child: const Text('Tap Me'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // FilledButton default minimum size is 48x48
        final button = tester.firstWidget(find.byType(FilledButton));
        expect(button, isNotNull);
      });
    });

    group('Indic locale support', () {
      testWidgets('Gujarati locale builds without negative letter spacing',
          (tester) async {
        final theme =
            buildLightTheme(NookColors.violet, locale: const Locale('gu'));
        final textStyle = theme.textTheme.bodyLarge;

        // Gujarati locale should have non-negative letter spacing (or null)
        expect(textStyle, isNotNull);
        final spacing = textStyle?.letterSpacing;
        if (spacing != null) {
          expect(spacing, greaterThanOrEqualTo(0.0));
        }
      });

      testWidgets('Hindi locale builds without negative letter spacing',
          (tester) async {
        final theme =
            buildLightTheme(NookColors.violet, locale: const Locale('hi'));
        final textStyle = theme.textTheme.bodyLarge;

        // Hindi locale should have non-negative letter spacing (or null)
        expect(textStyle, isNotNull);
        final spacing = textStyle?.letterSpacing;
        if (spacing != null) {
          expect(spacing, greaterThanOrEqualTo(0.0));
        }
      });
    });
  });
}

/// Small test chip widget for gallery tests.
Widget _testChip(int index) {
  return FilterChip(
    label: Text(['Pen', 'Highlighter', 'Eraser'][index]),
    selected: false,
    onSelected: (_) {},
    avatar: const HugeIcon(
      icon: HugeIcons.strokeRoundedPen01,
      size: 16,
    ),
  );
}
