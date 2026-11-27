import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/theme/high_contrast_theme.dart';
import 'package:nook/core/theme/nook_tokens.dart';
import 'package:nook/features/home/widgets/nook_hero.dart';

/// Reference relative luminance implementation according to WCAG 2.1 specs.
double _wcagRelativeLuminance(Color color) {
  double channel(double c) {
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel(color.r);
  final g = channel(color.g);
  final b = channel(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Reference WCAG 2.1 contrast ratio between two colors (range: 1.0 to 21.0).
double _wcagContrastRatio(Color c1, Color c2) {
  final l1 = _wcagRelativeLuminance(c1);
  final l2 = _wcagRelativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('HighContrastTheme.contrastRatio & relativeLuminance utility', () {
    test('computes relative luminance correctly for pure white and black', () {
      expect(
        HighContrastTheme.relativeLuminance(const Color(0xFFFFFFFF)),
        closeTo(1.0, 0.001),
      );
      expect(
        HighContrastTheme.relativeLuminance(const Color(0xFF000000)),
        closeTo(0.0, 0.001),
      );
    });

    test('computes maximum contrast ratio 21:1 for pure black and pure white',
        () {
      final ratio = HighContrastTheme.contrastRatio(
        const Color(0xFF000000),
        const Color(0xFFFFFFFF),
      );
      expect(ratio, closeTo(21.0, 0.01));
    });

    test('matches reference WCAG calculation', () {
      const c1 = Color(0xFF000000);
      const c2 = Color(0xFFFFFFFF);
      expect(
        HighContrastTheme.contrastRatio(c1, c2),
        equals(_wcagContrastRatio(c1, c2)),
      );
    });
  });

  group('HighContrastTheme.build', () {
    test('returns light theme with Brightness.light', () {
      final theme = HighContrastTheme.build(Brightness.light);
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });

    test('returns dark theme with Brightness.dark', () {
      final theme = HighContrastTheme.build(Brightness.dark);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });
  });

  group('WCAG AAA Contrast Requirements (Light Mode)', () {
    final theme = HighContrastTheme.build(Brightness.light);
    final scheme = theme.colorScheme;

    test('surface is pure white and onSurface is pure black', () {
      expect(scheme.surface, const Color(0xFFFFFFFF));
      expect(scheme.onSurface, const Color(0xFF000000));
    });

    test('onSurface against surface achieves WCAG AAA body text ratio (>= 7:1)',
        () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onSurface,
        scheme.surface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Light onSurface on surface must meet WCAG AAA (>= 7.0:1)',
      );
    });

    test('onPrimary against primary achieves WCAG AAA ratio (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onPrimary,
        scheme.primary,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Light onPrimary on primary must meet WCAG AAA (>= 7.0:1)',
      );
    });

    test('onSecondary against secondary achieves WCAG AAA ratio (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onSecondary,
        scheme.secondary,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Light onSecondary on secondary must meet WCAG AAA (>= 7.0:1)',
      );
    });

    test('outline against surface achieves WCAG AAA ratio (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.outline,
        scheme.surface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Light outline on surface must meet high contrast (>= 7.0:1)',
      );
    });

    test('onSurfaceVariant against surface achieves WCAG AAA (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onSurfaceVariant,
        scheme.surface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason:
            'Light onSurfaceVariant on surface must meet WCAG AAA (>= 7.0:1)',
      );
    });

    test('onError against error achieves WCAG AAA (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onError,
        scheme.error,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Light onError on error must meet WCAG AAA (>= 7.0:1)',
      );
    });
  });

  group('WCAG AAA Contrast Requirements (Dark Mode)', () {
    final theme = HighContrastTheme.build(Brightness.dark);
    final scheme = theme.colorScheme;

    test('surface is pure black and onSurface is pure white', () {
      expect(scheme.surface, const Color(0xFF000000));
      expect(scheme.onSurface, const Color(0xFFFFFFFF));
    });

    test('onSurface against surface achieves WCAG AAA body text ratio (>= 7:1)',
        () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onSurface,
        scheme.surface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Dark onSurface on surface must meet WCAG AAA (>= 7.0:1)',
      );
    });

    test('onPrimary against primary achieves WCAG AAA ratio (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onPrimary,
        scheme.primary,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Dark onPrimary on primary must meet WCAG AAA (>= 7.0:1)',
      );
    });

    test('onSecondary against secondary achieves WCAG AAA ratio (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onSecondary,
        scheme.secondary,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Dark onSecondary on secondary must meet WCAG AAA (>= 7.0:1)',
      );
    });

    test('outline against surface achieves WCAG AAA ratio (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.outline,
        scheme.surface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Dark outline on surface must meet high contrast (>= 7.0:1)',
      );
    });

    test('onSurfaceVariant against surface achieves WCAG AAA (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onSurfaceVariant,
        scheme.surface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason:
            'Dark onSurfaceVariant on surface must meet WCAG AAA (>= 7.0:1)',
      );
    });

    test('onError against error achieves WCAG AAA (>= 7:1)', () {
      final ratio = HighContrastTheme.contrastRatio(
        scheme.onError,
        scheme.error,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(7.0),
        reason: 'Dark onError on error must meet WCAG AAA (>= 7.0:1)',
      );
    });
  });

  group('Typography & Font Floor Constraints', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final mode = brightness == Brightness.light ? 'Light' : 'Dark';
      test('$mode mode enforces minimum font size floor >= 12sp for all styles',
          () {
        final theme = HighContrastTheme.build(brightness);
        final textTheme = theme.textTheme;

        final styles = <String, TextStyle?>{
          'displayLarge': textTheme.displayLarge,
          'displayMedium': textTheme.displayMedium,
          'displaySmall': textTheme.displaySmall,
          'headlineLarge': textTheme.headlineLarge,
          'headlineMedium': textTheme.headlineMedium,
          'headlineSmall': textTheme.headlineSmall,
          'titleLarge': textTheme.titleLarge,
          'titleMedium': textTheme.titleMedium,
          'titleSmall': textTheme.titleSmall,
          'bodyLarge': textTheme.bodyLarge,
          'bodyMedium': textTheme.bodyMedium,
          'bodySmall': textTheme.bodySmall,
          'labelLarge': textTheme.labelLarge,
          'labelMedium': textTheme.labelMedium,
          'labelSmall': textTheme.labelSmall,
        };

        for (final entry in styles.entries) {
          expect(
            entry.value,
            isNotNull,
            reason: '$mode ${entry.key} must be defined',
          );
          expect(
            entry.value!.fontSize,
            isNotNull,
            reason: '$mode ${entry.key} must specify fontSize',
          );
          expect(
            entry.value!.fontSize!,
            greaterThanOrEqualTo(12.0),
            reason:
                '$mode ${entry.key} fontSize (${entry.value!.fontSize}) must be >= 12sp floor',
          );
        }
      });

      test(
          '$mode mode attaches NookTokens with fontFloor >= 12.0 and minTapTarget >= 48.0',
          () {
        final theme = HighContrastTheme.build(brightness);
        final tokens = theme.extension<NookTokens>();
        expect(tokens, isNotNull);
        expect(tokens!.fontFloor, greaterThanOrEqualTo(12.0));
        expect(tokens.eyebrowSize, greaterThanOrEqualTo(12.0));
        expect(tokens.minTapTarget, greaterThanOrEqualTo(48.0));
      });
    }
  });

  group('Accessible Component Styling in High Contrast', () {
    test('Light mode component borders and outlines have high contrast', () {
      final theme = HighContrastTheme.build(Brightness.light);
      final scheme = theme.colorScheme;

      // Card border uses scheme.outline with solid stroke
      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder?;
      expect(cardShape, isNotNull);
      expect(cardShape!.side.color, scheme.outline);
      expect(cardShape.side.width, greaterThanOrEqualTo(1.5));

      // Divider uses scheme.outline with visible thickness
      expect(theme.dividerTheme.color, scheme.outline);
      expect(theme.dividerTheme.thickness, greaterThanOrEqualTo(1.0));

      // Input decoration has high-contrast borders
      final inputBorder =
          theme.inputDecorationTheme.border as OutlineInputBorder?;
      expect(inputBorder, isNotNull);
      expect(inputBorder!.borderSide.color, scheme.outline);
      expect(inputBorder.borderSide.width, greaterThanOrEqualTo(1.5));
    });

    test('Dark mode component borders and outlines have high contrast', () {
      final theme = HighContrastTheme.build(Brightness.dark);
      final scheme = theme.colorScheme;

      final cardShape = theme.cardTheme.shape as RoundedRectangleBorder?;
      expect(cardShape, isNotNull);
      expect(cardShape!.side.color, scheme.outline);
      expect(cardShape.side.width, greaterThanOrEqualTo(1.5));

      expect(theme.dividerTheme.color, scheme.outline);
      expect(theme.dividerTheme.thickness, greaterThanOrEqualTo(1.0));

      final inputBorder =
          theme.inputDecorationTheme.border as OutlineInputBorder?;
      expect(inputBorder, isNotNull);
      expect(inputBorder!.borderSide.color, scheme.outline);
      expect(inputBorder.borderSide.width, greaterThanOrEqualTo(1.5));
    });
  });

  group('Locale Support', () {
    test('handles Indic script locale without breaking ligatures', () {
      final guTheme = HighContrastTheme.build(
        Brightness.light,
        locale: const Locale('gu'),
      );
      expect(guTheme.textTheme.displayLarge?.letterSpacing, equals(0.0));
      expect(guTheme.textTheme.titleLarge?.letterSpacing, equals(0.0));

      final defaultTheme = HighContrastTheme.build(Brightness.light);
      expect(defaultTheme.textTheme.displayLarge?.letterSpacing, equals(-1.0));
    });
  });

  group('High Contrast Sync Status States', () {
    Widget buildSyncPillHarness(NookSyncStatus status, Brightness brightness) {
      final theme = HighContrastTheme.build(brightness);
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              NookHeroSliver(
                noteCount: 10,
                syncStatus: status,
                animate: false,
                onSearch: () {},
                onSyncTap: () {},
                onCaptureText: () {},
                onCaptureChecklist: () {},
                onCaptureDoodle: () {},
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders synced state in high-contrast light and dark',
        (tester) async {
      await tester.pumpWidget(
          buildSyncPillHarness(NookSyncStatus.synced, Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('Synced'), findsOneWidget);

      await tester.pumpWidget(
          buildSyncPillHarness(NookSyncStatus.synced, Brightness.dark));
      await tester.pumpAndSettle();
      expect(find.text('Synced'), findsOneWidget);
    });

    testWidgets('renders syncing state in high-contrast light and dark',
        (tester) async {
      await tester.pumpWidget(
          buildSyncPillHarness(NookSyncStatus.syncing, Brightness.light));
      await tester.pump();
      expect(find.text('Syncing'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpWidget(
          buildSyncPillHarness(NookSyncStatus.syncing, Brightness.dark));
      await tester.pump();
      expect(find.text('Syncing'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders conflict state in high-contrast light and dark',
        (tester) async {
      await tester.pumpWidget(
          buildSyncPillHarness(NookSyncStatus.conflict, Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('Needs review'), findsOneWidget);

      await tester.pumpWidget(
          buildSyncPillHarness(NookSyncStatus.conflict, Brightness.dark));
      await tester.pumpAndSettle();
      expect(find.text('Needs review'), findsOneWidget);
    });

    testWidgets('renders localOnly state in high-contrast light and dark',
        (tester) async {
      await tester.pumpWidget(
          buildSyncPillHarness(NookSyncStatus.localOnly, Brightness.light));
      await tester.pumpAndSettle();
      expect(find.text('On this device'), findsOneWidget);

      await tester.pumpWidget(
          buildSyncPillHarness(NookSyncStatus.localOnly, Brightness.dark));
      await tester.pumpAndSettle();
      expect(find.text('On this device'), findsOneWidget);
    });
  });
}
