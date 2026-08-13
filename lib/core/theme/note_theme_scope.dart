import 'package:flutter/material.dart';

/// Provides theme tokens and dynamic typography tailored to a note's seed color.
class NoteThemeScope extends InheritedWidget {
  const NoteThemeScope({
    super.key,
    required this.colorScheme,
    required this.textTheme,
    required super.child,
  });

  final ColorScheme colorScheme;
  final TextTheme textTheme;

  static NoteThemeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NoteThemeScope>();
  }

  static ColorScheme of(BuildContext context) {
    return maybeOf(context)?.colorScheme ?? Theme.of(context).colorScheme;
  }

  static TextTheme textThemeOf(BuildContext context) {
    return maybeOf(context)?.textTheme ?? Theme.of(context).textTheme;
  }

  /// Builds a custom [TextTheme] based on the primary seed hue.
  ///
  /// Warm seeds (Terracotta/Gold/Rose): Editorial Serif Style.
  /// Cool seeds (Sage/Navy/Cyan): Precision High-Tracking Modern Style.
  static TextTheme buildDynamicTextTheme(
    BuildContext context,
    ColorScheme scheme,
  ) {
    final base = Theme.of(context).textTheme;
    final hue = HSLColor.fromColor(scheme.primary).hue;
    final isWarm = (hue >= 0 && hue <= 60) || hue >= 330;

    if (isWarm) {
      return base.copyWith(
        displayLarge: base.displayLarge?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w400,
          fontSize: 72, // Dramatic scaling for macro-typography
          height: 0.95, // Extremely tight leading for luxury feel
          letterSpacing: -2.0,
          color: scheme.onSurface,
        ),
        displayMedium: base.displayMedium?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w400,
          fontSize: 48,
          height: 1.0,
          letterSpacing: -1.0,
          color: scheme.onSurface,
        ),
        displaySmall: base.displaySmall?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
        ),
        headlineLarge: base.headlineLarge?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: scheme.onSurface,
        ),
        headlineMedium: base.headlineMedium?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: scheme.onSurface,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: scheme.onSurface,
        ),
        titleSmall: base.titleSmall?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: scheme.onSurface,
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          height: 1.6,
          fontSize: 16,
          letterSpacing: 0.15,
          color: scheme.onSurface,
        ),
        bodyMedium: base.bodyMedium?.copyWith(
          height: 1.55,
          fontSize: 14,
          letterSpacing: 0.1,
          color: scheme.onSurface,
        ),
        bodySmall: base.bodySmall?.copyWith(
          height: 1.45,
          fontSize: 12,
          letterSpacing: 0.05,
          color: scheme.onSurface,
        ),
        labelLarge: base.labelLarge?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: scheme.primary,
        ),
        labelMedium: base.labelMedium?.copyWith(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: scheme.primary,
        ),
        labelSmall: base.labelSmall?.copyWith(
          fontWeight: FontWeight.w700, // Bold for editorial impact
          letterSpacing: 2.5, // Extreme tracking — editorial hallmark
          color: scheme.primary,
        ),
      );
    }

    // Cool seeds: Precision High-Tracking Modern Style
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -1.5,
        color: scheme.onSurface,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -1.2,
        color: scheme.onSurface,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: -1.0,
        color: scheme.onSurface,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
        color: scheme.onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: scheme.onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: scheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: scheme.onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: scheme.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        height: 1.55,
        fontSize: 15.5,
        letterSpacing: 0.2,
        color: scheme.onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        height: 1.5,
        fontSize: 14,
        letterSpacing: 0.15,
        color: scheme.onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        height: 1.4,
        fontSize: 12,
        letterSpacing: 0.1,
        color: scheme.onSurface,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: scheme.primary,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: scheme.primary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: scheme.primary,
      ),
    );
  }

  @override
  bool updateShouldNotify(NoteThemeScope oldWidget) {
    return oldWidget.colorScheme != colorScheme ||
        oldWidget.textTheme != textTheme;
  }
}
