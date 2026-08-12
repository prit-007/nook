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
  static TextTheme buildDynamicTextTheme(
    BuildContext context,
    ColorScheme scheme,
  ) {
    final base = Theme.of(context).textTheme;
    final hue = HSLColor.fromColor(scheme.primary).hue;

    // Warm seeds (Terracotta/Gold/Rose): Editorial Serif Style
    if ((hue >= 0 && hue <= 60) || hue >= 330) {
      return base.copyWith(
        headlineLarge: base.headlineLarge?.copyWith(
          fontFamily: 'Serif',
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: scheme.onSurface,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontFamily: 'Serif',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
        bodyLarge: base.bodyLarge?.copyWith(
          height: 1.6,
          fontSize: 16,
          letterSpacing: 0.15,
          color: scheme.onSurface,
        ),
      );
    }

    // Cool seeds (Sage/Navy/Cyan): Precision High-Tracking Modern Style
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
        color: scheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: scheme.onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        height: 1.55,
        fontSize: 15.5,
        letterSpacing: 0.2,
        color: scheme.onSurface,
      ),
    );
  }

  @override
  bool updateShouldNotify(NoteThemeScope oldWidget) {
    return oldWidget.colorScheme != colorScheme ||
        oldWidget.textTheme != textTheme;
  }
}
