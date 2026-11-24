import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/theme/app_theme.dart';
import 'package:nook/core/theme/design_tokens.dart';

/// Calculates sRGB relative luminance according to WCAG 2.1 specs.
double _relativeLuminance(Color color) {
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

/// Computes the WCAG 2.1 contrast ratio between two colors (range: 1.0 to 21.0).
double _contrastRatio(Color c1, Color c2) {
  final l1 = _relativeLuminance(c1);
  final l2 = _relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Blends a semi-transparent foreground color onto an opaque background.
Color _composite(Color fg, Color bg) {
  final alpha = fg.a;
  return Color.from(
    alpha: 1.0,
    red: fg.r * alpha + bg.r * (1 - alpha),
    green: fg.g * alpha + bg.g * (1 - alpha),
    blue: fg.b * alpha + bg.b * (1 - alpha),
  );
}

void main() {
  group('WCAG Contrast Audit across all 12 seeds', () {
    for (int i = 0; i < NookColors.seeds.length; i++) {
      final seed = NookColors.seeds[i];
      final name = NookColors.seedNames[i];

      group('Seed: $name ($seed)', () {
        test('Light theme passes WCAG accessibility contrast', () {
          final theme = buildLightTheme(seed);
          final scheme = theme.colorScheme;

          // onSurface on surface (body text floor: 4.5:1)
          final surfaceRatio = _contrastRatio(scheme.onSurface, scheme.surface);
          expect(surfaceRatio, greaterThanOrEqualTo(4.5),
              reason: 'Light onSurface on surface must meet WCAG AA (4.5:1)');

          // onSurfaceVariant on surfaceContainerLow (body text over low surface: 4.5:1)
          final variantContainerRatio = _contrastRatio(
              scheme.onSurfaceVariant, scheme.surfaceContainerLow);
          expect(variantContainerRatio, greaterThanOrEqualTo(4.5),
              reason:
                  'Light onSurfaceVariant on surfaceContainerLow must meet WCAG AA (4.5:1)');

          // onPrimary on primary (large text / button: 3.0:1)
          final primaryRatio = _contrastRatio(scheme.onPrimary, scheme.primary);
          expect(primaryRatio, greaterThanOrEqualTo(3.0),
              reason: 'Light onPrimary on primary must meet at least 3.0:1');

          // onPrimaryContainer on primaryContainer
          final containerRatio = _contrastRatio(
              scheme.onPrimaryContainer, scheme.primaryContainer);
          expect(containerRatio, greaterThanOrEqualTo(3.5),
              reason:
                  'Light onPrimaryContainer on primaryContainer must meet at least 3.5:1');

          // Tokens attached and configured
          final tokens = theme.extension<NookTokens>();
          expect(tokens, isNotNull);
          expect(tokens!.minTapTarget, equals(48.0));
          expect(tokens.fontFloor, equals(12.0));
          expect(tokens.eyebrowSize, equals(12.0));

          // Semi-transparent border / hairline layered over container remains visible
          final compositedBorder =
              _composite(tokens.borderSubtle, scheme.surfaceContainerHigh);
          expect(compositedBorder, isNot(equals(scheme.surfaceContainerHigh)));
        });

        test('Dark theme passes WCAG accessibility contrast', () {
          final theme = buildDarkTheme(seed, amoled: false);
          final scheme = theme.colorScheme;

          // onSurface on surface
          final surfaceRatio = _contrastRatio(scheme.onSurface, scheme.surface);
          expect(surfaceRatio, greaterThanOrEqualTo(4.5),
              reason: 'Dark onSurface on surface must meet WCAG AA (4.5:1)');

          // onSurfaceVariant on surfaceContainerLow
          final variantContainerRatio = _contrastRatio(
              scheme.onSurfaceVariant, scheme.surfaceContainerLow);
          expect(variantContainerRatio, greaterThanOrEqualTo(4.5),
              reason:
                  'Dark onSurfaceVariant on surfaceContainerLow must meet WCAG AA (4.5:1)');

          // onPrimary on primary
          final primaryRatio = _contrastRatio(scheme.onPrimary, scheme.primary);
          expect(primaryRatio, greaterThanOrEqualTo(3.0),
              reason: 'Dark onPrimary on primary must meet at least 3.0:1');

          final tokens = theme.extension<NookTokens>();
          expect(tokens, isNotNull);
          expect(tokens!.fontFloor, equals(12.0));
        });

        test('AMOLED true-black theme passes WCAG contrast', () {
          final theme = buildDarkTheme(seed, amoled: true);
          final scheme = theme.colorScheme;

          // Base surface is pure black
          expect(scheme.surface, equals(const Color(0xFF000000)));

          // onSurface on true black
          final surfaceRatio = _contrastRatio(scheme.onSurface, scheme.surface);
          expect(surfaceRatio, greaterThanOrEqualTo(4.5),
              reason: 'AMOLED onSurface on black must meet WCAG AA (4.5:1)');

          // onSurfaceVariant on black
          final variantRatio =
              _contrastRatio(scheme.onSurfaceVariant, scheme.surface);
          expect(variantRatio, greaterThanOrEqualTo(4.5),
              reason:
                  'AMOLED onSurfaceVariant on black must meet WCAG AA (4.5:1)');

          final tokens = theme.extension<NookTokens>();
          expect(tokens, isNotNull);
          expect(tokens!.fontFloor, equals(12.0));
        });
      });
    }

    test('Locale-aware letter spacing handles Indic scripts safely', () {
      const guLocale = Locale('gu');
      const hiLocale = Locale('hi');
      const enLocale = Locale('en');

      // Negative spacing clamped to zero for Indic locales to preserve glyph ligature shaping
      expect(localeAwareLetterSpacing(guLocale, -1.0), equals(0.0));
      expect(localeAwareLetterSpacing(hiLocale, -0.5), equals(0.0));
      // Positive spacing preserved
      expect(localeAwareLetterSpacing(guLocale, 0.5), equals(0.5));
      // English / Latin negative spacing preserved
      expect(localeAwareLetterSpacing(enLocale, -1.0), equals(-1.0));

      final guTheme =
          buildLightTheme(NookColors.violet, locale: const Locale('gu'));
      expect(guTheme.textTheme.displayLarge?.letterSpacing, equals(0.0));
      expect(guTheme.textTheme.titleLarge?.letterSpacing, equals(0.0));

      final defaultTheme = buildLightTheme(NookColors.violet);
      expect(defaultTheme.textTheme.displayLarge?.letterSpacing, equals(-1.0));
    });
  });
}
