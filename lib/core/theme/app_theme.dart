import 'package:flutter/material.dart';

/// Builds a ColorScheme from a seed color.
ColorScheme buildSchemeForSeed(Color seed, Brightness brightness) {
  return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
}

/// Returns the app's light theme for a given seed color.
/// This is the single source of truth for all light-mode styling.
ThemeData buildLightTheme(Color seed) {
  final scheme = buildSchemeForSeed(seed, Brightness.light);
  return _buildTheme(scheme);
}

/// Returns the app's dark theme for a given seed color.
/// This is the single source of truth for all dark-mode styling.
ThemeData buildDarkTheme(Color seed) {
  final scheme = buildSchemeForSeed(seed, Brightness.dark);
  return _buildTheme(scheme);
}

/// Builds a complete [ThemeData] from a [ColorScheme].
///
/// Centralises all component-level theming so every screen in the app
/// inherits the same typography, shapes, and surface tints.
ThemeData _buildTheme(ColorScheme scheme) {
  final isLight = scheme.brightness == Brightness.light;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: null, // system default

    // ── Text theme ──────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w400),
      displayMedium: TextStyle(fontWeight: FontWeight.w400),
      displaySmall: TextStyle(fontWeight: FontWeight.w400),
      headlineLarge: TextStyle(fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400, height: 1.5),
      bodySmall: TextStyle(fontWeight: FontWeight.w400, height: 1.4),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
    ),

    // ── Scaffold ────────────────────────────────────────────────
    scaffoldBackgroundColor: scheme.surface,

    // ── AppBar ──────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),

    // ── Cards ───────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      color: isLight
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),

    // ── Bottom Navigation ───────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: scheme.onSurface, fontSize: 12),
      ),
    ),

    // ── Floating Action Button ──────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // ── Bottom Sheet ────────────────────────────────────────────
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),

    // ── Dialog ──────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),

    // ── Chips ───────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(color: scheme.onSurface),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ── Input Decoration ────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // ── ListTile ────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ── Switch ──────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return scheme.outline;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return scheme.surfaceContainerHighest;
      }),
    ),

    // ── Radio ───────────────────────────────────────────────────
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return scheme.onSurfaceVariant;
      }),
    ),

    // ── Slider ──────────────────────────────────────────────────
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
    ),

    // ── Divider ─────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.3),
      thickness: 1,
      space: 1,
    ),

    // ── SnackBar ────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ── Progress Indicators ─────────────────────────────────────
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}
