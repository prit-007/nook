import 'package:flutter/material.dart';

/// Builds a ColorScheme from a seed color.
ColorScheme buildSchemeForSeed(Color seed, Brightness brightness) {
  return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
}

/// Returns the app's light theme for a given seed color.
/// This is the single source of truth for all light-mode styling.
ThemeData buildLightTheme(Color seed) {
  final scheme = buildSchemeForSeed(seed, Brightness.light);
  return _buildTheme(scheme, amoled: false);
}

/// Returns the app's dark theme for a given seed color.
/// This is the single source of truth for all dark-mode styling.
/// When [amoled] is true, neutral surfaces are overridden to a true-black
/// ramp so OLED pixels turn off instead of rendering dark gray.
ThemeData buildDarkTheme(Color seed, {bool amoled = false}) {
  var scheme = buildSchemeForSeed(seed, Brightness.dark);
  if (amoled) {
    scheme = applyAmoledSurfaces(scheme);
  }
  return _buildTheme(scheme, amoled: amoled);
}

/// AMOLED true-black surface ramp.
///
/// The base surface is pure black so OLED pixels power down. A very subtle
/// near-black elevation ramp keeps elevated surfaces distinguishable without
/// reintroducing the standard M3 gray wash.
const Color kAmoledSurface = Color(0xFF000000);
const Color kAmoledSurfaceDim = Color(0xFF000000);
const Color kAmoledSurfaceBright = Color(0xFF0A0A0A);
const Color kAmoledSurfaceContainerLowest = Color(0xFF000000);
const Color kAmoledSurfaceContainerLow = Color(0xFF0A0A0A);
const Color kAmoledSurfaceContainer = Color(0xFF121212);
const Color kAmoledSurfaceContainerHigh = Color(0xFF1A1A1A);
const Color kAmoledSurfaceContainerHighest = Color(0xFF222222);

/// Returns a copy of [scheme] whose neutral surface roles are replaced with
/// the AMOLED ramp. Seed-derived hues (primary/secondary/tertiary/containers)
/// are preserved so the Material You identity survives in true-black mode.
ColorScheme applyAmoledSurfaces(ColorScheme scheme) {
  return scheme.copyWith(
    surface: kAmoledSurface,
    surfaceDim: kAmoledSurfaceDim,
    surfaceBright: kAmoledSurfaceBright,
    surfaceContainerLowest: kAmoledSurfaceContainerLowest,
    surfaceContainerLow: kAmoledSurfaceContainerLow,
    surfaceContainer: kAmoledSurfaceContainer,
    surfaceContainerHigh: kAmoledSurfaceContainerHigh,
    surfaceContainerHighest: kAmoledSurfaceContainerHighest,
  );
}

/// Builds a complete [ThemeData] from a [ColorScheme].
///
/// Centralises all component-level theming so every screen in the app
/// inherits the same typography, shapes, and surface tints.
/// When [amoled] is true, elevated components use solid near-black fills and
/// transparent surface tints so the M3 elevation tint cannot wash out black.
ThemeData _buildTheme(ColorScheme scheme, {bool amoled = false}) {
  final isLight = scheme.brightness == Brightness.light;
  final surfaceTint = amoled ? Colors.transparent : null;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,

    // ── Text theme ──────────────────────────────────────────────
    // Playfair Display for editorial display/headline styles.
    // Inter for all body, title, and label styles.
    textTheme: const TextTheme(
      // ── Serif: Display & Headlines ──────────────────────
      displayLarge: TextStyle(
        fontFamily: 'Playfair Display',
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Playfair Display',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Playfair Display',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Playfair Display',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Playfair Display',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Playfair Display',
        fontWeight: FontWeight.w600,
      ),

      // ── Sans-Serif: Titles, Body, Labels ────────────────
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    ),

    // ── Scaffold ────────────────────────────────────────────────
    scaffoldBackgroundColor: scheme.surface,

    // ── AppBar ──────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: surfaceTint,
      foregroundColor: scheme.onSurface,
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ).copyWith(
        color: scheme.onSurface,
        fontSize: 18,
      ),
    ),

    // ── Cards ───────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      color: isLight
          ? scheme.surfaceContainerLowest
          : amoled
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      surfaceTintColor: surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Bottom Navigation ───────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor: scheme.surface,
      surfaceTintColor: surfaceTint,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
        ).copyWith(
          color: scheme.onSurface,
          fontSize: 12,
        ),
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
      surfaceTintColor: surfaceTint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
    ),

    // ── Dialog ──────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),

    // ── Chips ───────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: isLight
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : amoled
              ? scheme.surfaceContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      selectedColor: scheme.primaryContainer,
      labelStyle: const TextStyle(fontFamily: 'Inter').copyWith(
        color: scheme.onSurface,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ── Input Decoration ────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: amoled
          ? scheme.surfaceContainer
          : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
      backgroundColor:
          amoled ? scheme.surfaceContainerHigh : scheme.inverseSurface,
      contentTextStyle: TextStyle(
        color: amoled ? scheme.onSurface : scheme.onInverseSurface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ── Progress Indicators ─────────────────────────────────────
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),

    // ── NavigationRail ──────────────────────────────────────────
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),

    // ── TabBar ──────────────────────────────────────────────────
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      indicatorColor: scheme.primary,
    ),

    // ── PopupMenu ───────────────────────────────────────────────
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: surfaceTint,
    ),
  );
}
