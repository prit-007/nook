import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'note_theme_scope.dart';

/// Builds a brightness-aware [ColorScheme] for a note's color seed.
///
/// Falls back to the ambient [Theme] scheme when [colorSeed] is null or empty.
///
/// Neutral surface roles (surface, surfaceContainer*, etc.) are inherited from
/// the ambient scheme so app-wide surface overrides — like AMOLED true-black
/// dark mode — propagate to notes and doodles while the note's seed identity
/// (primary/secondary/tertiary/containers) stays intact.
ColorScheme noteSchemeFor(BuildContext context, String? colorSeed) {
  final ambient = Theme.of(context).colorScheme;
  if (colorSeed == null || colorSeed.isEmpty) {
    return ambient;
  }
  final seed = NookColors.parseHex(colorSeed);
  final noteScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: ambient.brightness,
  );
  return noteScheme.copyWith(
    surface: ambient.surface,
    surfaceDim: ambient.surfaceDim,
    surfaceBright: ambient.surfaceBright,
    surfaceContainerLowest: ambient.surfaceContainerLowest,
    surfaceContainerLow: ambient.surfaceContainerLow,
    surfaceContainer: ambient.surfaceContainer,
    surfaceContainerHigh: ambient.surfaceContainerHigh,
    surfaceContainerHighest: ambient.surfaceContainerHighest,
  );
}

/// Builds a custom [TextTheme] based on the note's primary hue.
///
/// Warm seeds (coral/amber/rose/peach) → editorial serif style.
/// Cool seeds (violet/teal/sky/slate/indigo/mint/lavender) → precision modern.
/// Covers headline, title, body, display, and label for full card/preview coverage.
TextTheme noteTypographyFor(BuildContext context, ColorScheme scheme) {
  return NoteThemeScope.buildDynamicTextTheme(context, scheme);
}

/// Convenience widget that wraps [child] in a [NoteThemeScope].
///
/// Use this to make a note's color and typography available to all descendants.
class NoteTheme extends StatelessWidget {
  const NoteTheme({
    super.key,
    required this.colorSeed,
    required this.child,
  });

  final String? colorSeed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = noteSchemeFor(context, colorSeed);
    final textTheme = noteTypographyFor(context, scheme);
    return NoteThemeScope(
      colorScheme: scheme,
      textTheme: textTheme,
      child: child,
    );
  }
}

/// Extension on [BuildContext] for convenient per-note theme access.
extension NoteThemeExtension on BuildContext {
  /// Whether the current note's primary hue is warm (editorial serif).
  bool get isNoteWarm {
    final scheme = NoteThemeScope.of(this);
    final hue = HSLColor.fromColor(scheme.primary).hue;
    return (hue >= 0 && hue <= 60) || hue >= 330;
  }
}
