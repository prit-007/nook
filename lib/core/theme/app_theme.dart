import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nook_tokens.dart';

export 'nook_tokens.dart';

/// Font fallbacks for Indic scripts (Gujarati, Devanagari/Hindi) ensuring
/// seamless multilingual rendering without glyph clipping or mismatched metrics.
const List<String> kIndicSansFallbacks = [
  'Noto Sans Gujarati',
  'Noto Sans Devanagari',
  'sans-serif',
];

const List<String> kIndicSerifFallbacks = [
  'Noto Serif Gujarati',
  'Noto Serif Devanagari',
  'serif',
];

/// Helper that ensures tracking does not break joined ligatures in Indic scripts.
double localeAwareLetterSpacing(Locale? locale, double letterSpacing) {
  if (locale != null) {
    final lang = locale.languageCode.toLowerCase();
    if (lang == 'gu' || lang == 'hi' || lang == 'mr' || lang == 'ne') {
      return letterSpacing < 0 ? 0.0 : letterSpacing;
    }
  }
  return letterSpacing;
}

/// Builds a ColorScheme from a seed color.
ColorScheme buildSchemeForSeed(Color seed, Brightness brightness) {
  return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
}

/// Returns the app's light theme for a given seed color.
/// This is the single source of truth for all light-mode styling.
ThemeData buildLightTheme(Color seed, {Locale? locale}) {
  final scheme = buildSchemeForSeed(seed, Brightness.light);
  return _buildTheme(scheme, amoled: false, locale: locale);
}

/// Returns the app's dark theme for a given seed color.
/// This is the single source of truth for all dark-mode styling.
/// When [amoled] is true, neutral surfaces are overridden to a true-black
/// ramp so OLED pixels turn off instead of rendering dark gray.
ThemeData buildDarkTheme(Color seed, {bool amoled = false, Locale? locale}) {
  var scheme = buildSchemeForSeed(seed, Brightness.dark);
  if (amoled) {
    scheme = applyAmoledSurfaces(scheme);
  }
  return _buildTheme(scheme, amoled: amoled, locale: locale);
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
ThemeData _buildTheme(ColorScheme scheme,
    {bool amoled = false, Locale? locale}) {
  final isLight = scheme.brightness == Brightness.light;
  final surfaceTint = amoled ? Colors.transparent : null;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,

    // ── Page Transitions ────────────────────────────────────────
    // Silky editorial transitions: slow fade + zoom for iOS/macOS,
    // predictive-back-aware fade for Android.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),

    // ── Text theme ──────────────────────────────────────────────
    // Playfair Display for editorial display/headline styles.
    // Inter for all body, title, and label styles.
    textTheme: TextTheme(
      // ── Serif: Display & Headlines ──────────────────────
      displayLarge: TextStyle(
        fontFamily: 'Playfair Display',
        fontFamilyFallback: kIndicSerifFallbacks,
        fontWeight: FontWeight.w700,
        letterSpacing: localeAwareLetterSpacing(locale, -1.0),
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Playfair Display',
        fontFamilyFallback: kIndicSerifFallbacks,
        fontWeight: FontWeight.w700,
        letterSpacing: localeAwareLetterSpacing(locale, -0.5),
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Playfair Display',
        fontFamilyFallback: kIndicSerifFallbacks,
        fontWeight: FontWeight.w600,
        letterSpacing: localeAwareLetterSpacing(locale, -0.3),
      ),
      headlineLarge: TextStyle(
        fontFamily: 'Playfair Display',
        fontFamilyFallback: kIndicSerifFallbacks,
        fontWeight: FontWeight.w700,
        letterSpacing: localeAwareLetterSpacing(locale, -0.5),
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Playfair Display',
        fontFamilyFallback: kIndicSerifFallbacks,
        fontWeight: FontWeight.w600,
        letterSpacing: localeAwareLetterSpacing(locale, -0.3),
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'Playfair Display',
        fontFamilyFallback: kIndicSerifFallbacks,
        fontWeight: FontWeight.w600,
      ),

      // ── Sans-Serif: Titles, Body, Labels ────────────────
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: kIndicSansFallbacks,
        fontWeight: FontWeight.w700,
        letterSpacing: localeAwareLetterSpacing(locale, -0.2),
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: kIndicSansFallbacks,
        fontWeight: FontWeight.w600,
        letterSpacing: localeAwareLetterSpacing(locale, -0.1),
      ),
      titleSmall: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: kIndicSansFallbacks,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: kIndicSansFallbacks,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: kIndicSansFallbacks,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: kIndicSansFallbacks,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: kIndicSansFallbacks,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: kIndicSansFallbacks,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: kIndicSansFallbacks,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    ),

    // ── Design Tokens ───────────────────────────────────────────
    extensions: [
      NookTokens.fromScheme(scheme, amoled: amoled),
    ],

    // ── Scaffold ────────────────────────────────────────────────
    scaffoldBackgroundColor: scheme.surface,

    // ── AppBar ──────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent, // Force transparent for clean look
      foregroundColor: scheme.onSurface,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
        statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ).copyWith(
        color: scheme.onSurface,
        fontSize: 16,
      ),
    ),

    // ── Cards ───────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      // Lowered alpha values create the perfect base for Glassmorphism
      color: isLight
          ? scheme.surfaceContainerLowest.withValues(alpha: 0.7)
          : amoled
              ? scheme.surfaceContainerHigh.withValues(alpha: 0.3)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.15),
      surfaceTintColor: surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NookTokens.kRadiusXl),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
      ),
    ),

    // ── Buttons (Material 3 Shapes & Padding) ───────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
        ),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
        ),
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
      ),
    ),

    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(
        amoled
            ? scheme.surfaceContainer
            : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusXl),
        ),
      ),
    ),

    splashFactory: InkSparkle.splashFactory,

    // ── Bottom Sheet ────────────────────────────────────────────
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: surfaceTint,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NookTokens.kRadiusXl),
        ),
      ),
      showDragHandle: true,
    ),

    // ── Dialog ──────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NookTokens.kRadiusXl),
      ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
      ),
    ),

    // ── Input Decoration ────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: amoled
          ? scheme.surfaceContainer
          : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // ── ListTile ────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
      ),
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
