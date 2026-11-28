import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'nook_tokens.dart';

/// Curated "Atmosphere" visual presets that pair surface warmth, ink contrast,
/// and border crispness beyond standard Light/Dark/AMOLED.
enum AtmospherePreset {
  standard,
  warmSepia,
  eInk,
  blueprint,
  chalkboard,
}

/// Builds [ThemeData] for a given [AtmospherePreset].
class AtmosphereTheme {
  const AtmosphereTheme._();

  static String labelOf(AtmospherePreset preset) {
    return switch (preset) {
      AtmospherePreset.standard => 'Standard',
      AtmospherePreset.warmSepia => 'Warm Sepia Paper',
      AtmospherePreset.eInk => 'E-Ink Monochrome',
      AtmospherePreset.blueprint => 'Blueprint',
      AtmospherePreset.chalkboard => 'Midnight Chalkboard',
    };
  }

  static ThemeData build(
    AtmospherePreset preset, {
    Color seedColor = NookColors.defaultSeed,
  }) {
    final ColorScheme scheme;
    switch (preset) {
      case AtmospherePreset.standard:
        scheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        );
      case AtmospherePreset.warmSepia:
        scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF7D5700),
          brightness: Brightness.light,
        ).copyWith(
          surface: const Color(0xFFF7F0E2),
          surfaceContainerLow: const Color(0xFFF1E7D4),
          surfaceContainerHigh: const Color(0xFFE7DAC2),
          onSurface: const Color(0xFF2B2118),
          onSurfaceVariant: const Color(0xFF5C4B3B),
        );
      case AtmospherePreset.eInk:
        scheme = const ColorScheme.light(
          primary: Color(0xFF111111),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF333333),
          onSecondary: Color(0xFFFFFFFF),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF000000),
          surfaceContainerLow: Color(0xFFF4F4F4),
          surfaceContainerHigh: Color(0xFFE5E5E5),
          outlineVariant: Color(0xFF9E9E9E),
        );
      case AtmospherePreset.blueprint:
        scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF64B5F6),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF0D2137),
          surfaceContainerLow: const Color(0xFF122C49),
          surfaceContainerHigh: const Color(0xFF18395E),
          onSurface: const Color(0xFFEBF5FF),
          onSurfaceVariant: const Color(0xFFB3D4F5),
        );
      case AtmospherePreset.chalkboard:
        scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF81C784),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF141B16),
          surfaceContainerLow: const Color(0xFF1B241E),
          surfaceContainerHigh: const Color(0xFF233027),
          onSurface: const Color(0xFFF1F5F2),
          onSurfaceVariant: const Color(0xFFB7C7BC),
        );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [
        NookTokens.fromScheme(scheme),
      ],
    );
  }
}
