import 'package:flutter/material.dart';

/// Builds a ColorScheme from a seed color.
ColorScheme buildSchemeForSeed(Color seed, Brightness brightness) {
  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
}

/// Returns the app's light theme for a given seed color.
ThemeData buildLightTheme(Color seed) {
  final scheme = buildSchemeForSeed(seed, Brightness.light);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: null, // system default
  );
}

/// Returns the app's dark theme for a given seed color.
ThemeData buildDarkTheme(Color seed) {
  final scheme = buildSchemeForSeed(seed, Brightness.dark);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: null,
  );
}
