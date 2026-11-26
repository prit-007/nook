import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

/// Clean, accessible High-Contrast ThemeData builders for Light and Dark modes.
///
/// Implements pure black/white high-contrast palettes satisfying WCAG 2.1 AAA
/// requirements (contrast ratio >= 7:1 for normal body text, >= 4.5:1 for large
/// text, and >= 3:1 for user interface component boundaries).
///
/// Enforces accessible constraints including a minimum font size floor of 12sp
/// and minimum touch targets of 48dp.
class HighContrastTheme {
  HighContrastTheme._();

  /// Calculates sRGB relative luminance according to WCAG 2.1 specifications.
  static double relativeLuminance(Color color) {
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

  /// Calculates the WCAG 2.1 contrast ratio between two colors (range: 1.0 to 21.0).
  static double contrastRatio(Color c1, Color c2) {
    final l1 = relativeLuminance(c1);
    final l2 = relativeLuminance(c2);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Builds a high-contrast [ColorScheme] for [brightness] meeting WCAG AAA.
  static ColorScheme buildScheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return isLight ? _lightScheme : _darkScheme;
  }

  /// High-contrast light color scheme (pure white surface with pure black ink).
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF000000),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF000000),
    onPrimaryContainer: Color(0xFFFFFFFF),
    secondary: Color(0xFF000000),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF0F0F0),
    onSecondaryContainer: Color(0xFF000000),
    tertiary: Color(0xFF000000),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF0F0F0),
    onTertiaryContainer: Color(0xFF000000),
    error: Color(0xFF8B0000),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFD1D1),
    onErrorContainer: Color(0xFF000000),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF000000),
    surfaceDim: Color(0xFFF5F5F5),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF5F5F5),
    surfaceContainerHigh: Color(0xFFEEEEEE),
    surfaceContainerHighest: Color(0xFFE0E0E0),
    onSurfaceVariant: Color(0xFF000000),
    outline: Color(0xFF000000),
    outlineVariant: Color(0xFF000000),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF000000),
    onInverseSurface: Color(0xFFFFFFFF),
    inversePrimary: Color(0xFFFFFFFF),
    surfaceTint: Colors.transparent,
  );

  /// High-contrast dark color scheme (pure black surface with pure white ink).
  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFFFFFFFF),
    onPrimaryContainer: Color(0xFF000000),
    secondary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF000000),
    secondaryContainer: Color(0xFF222222),
    onSecondaryContainer: Color(0xFFFFFFFF),
    tertiary: Color(0xFFFFFFFF),
    onTertiary: Color(0xFF000000),
    tertiaryContainer: Color(0xFF222222),
    onTertiaryContainer: Color(0xFFFFFFFF),
    error: Color(0xFFFF8080),
    onError: Color(0xFF000000),
    errorContainer: Color(0xFF4A0000),
    onErrorContainer: Color(0xFFFFFFFF),
    surface: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF),
    surfaceDim: Color(0xFF000000),
    surfaceBright: Color(0xFF1A1A1A),
    surfaceContainerLowest: Color(0xFF000000),
    surfaceContainerLow: Color(0xFF000000),
    surfaceContainer: Color(0xFF121212),
    surfaceContainerHigh: Color(0xFF1E1E1E),
    surfaceContainerHighest: Color(0xFF282828),
    onSurfaceVariant: Color(0xFFFFFFFF),
    outline: Color(0xFFFFFFFF),
    outlineVariant: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFFFFFFF),
    onInverseSurface: Color(0xFF000000),
    inversePrimary: Color(0xFF000000),
    surfaceTint: Colors.transparent,
  );

  /// Builds a complete high-contrast [ThemeData] for [brightness].
  static ThemeData build(Brightness brightness, {Locale? locale}) {
    final scheme = buildScheme(brightness);
    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,

      // ── Page Transitions ────────────────────────────────────────
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

      // ── Typography (Font Floor >= 12sp) ─────────────────────────
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Playfair Display',
          fontFamilyFallback: kIndicSerifFallbacks,
          fontSize: 57,
          fontWeight: FontWeight.w700,
          letterSpacing: localeAwareLetterSpacing(locale, -1.0),
          height: 1.1,
          color: scheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Playfair Display',
          fontFamilyFallback: kIndicSerifFallbacks,
          fontSize: 45,
          fontWeight: FontWeight.w700,
          letterSpacing: localeAwareLetterSpacing(locale, -0.5),
          height: 1.15,
          color: scheme.onSurface,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Playfair Display',
          fontFamilyFallback: kIndicSerifFallbacks,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: localeAwareLetterSpacing(locale, -0.3),
          color: scheme.onSurface,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Playfair Display',
          fontFamilyFallback: kIndicSerifFallbacks,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: localeAwareLetterSpacing(locale, -0.5),
          color: scheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Playfair Display',
          fontFamilyFallback: kIndicSerifFallbacks,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: localeAwareLetterSpacing(locale, -0.3),
          color: scheme.onSurface,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Playfair Display',
          fontFamilyFallback: kIndicSerifFallbacks,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kIndicSansFallbacks,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: localeAwareLetterSpacing(locale, -0.2),
          color: scheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kIndicSansFallbacks,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: localeAwareLetterSpacing(locale, -0.1),
          color: scheme.onSurface,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kIndicSansFallbacks,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kIndicSansFallbacks,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.6,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kIndicSansFallbacks,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: scheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kIndicSansFallbacks,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.4,
          color: scheme.onSurface,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kIndicSansFallbacks,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kIndicSansFallbacks,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        // Enforce fontFloor >= 12sp for labelSmall (default M3 is 11)
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: kIndicSansFallbacks,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: scheme.onSurface,
        ),
      ),

      // ── Design Tokens ───────────────────────────────────────────
      extensions: [
        NookTokens(
          hairline: scheme.outline,
          borderSubtle: scheme.outline,
          surfaceTintSubtle: Colors.transparent,
          scrim: Colors.black.withValues(alpha: 0.8),
          dockSurface: scheme.surface,
          dockBorder: scheme.outline,
          dockShadow: Colors.transparent,
          minTapTarget: NookTokens.kMinTapTarget,
          fontFloor: NookTokens.kFontFloor,
          eyebrowSize: NookTokens.kEyebrowSize,
        ),
      ],

      // ── AppBar ──────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: scheme.onSurface,
          fontSize: 18,
        ),
      ),

      // ── Cards (High Contrast 2px Border) ────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
          side: BorderSide(
            color: scheme.outline,
            width: 2.0,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Bottom Navigation ───────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.onPrimary);
          }
          return IconThemeData(color: scheme.onSurface);
        }),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
            fontSize: 12,
          ),
        ),
      ),

      // ── Floating Action Button ──────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
          side: BorderSide(color: scheme.outline, width: 2.0),
        ),
      ),

      // ── Buttons ─────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
            side: BorderSide(color: scheme.outline, width: 2.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
            side: BorderSide(color: scheme.outline, width: 2.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
          ),
          side: BorderSide(color: scheme.outline, width: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
            side: BorderSide(color: scheme.outline, width: 2.0),
          ),
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
        ),
      ),

      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surface),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NookTokens.kRadiusXl),
            side: BorderSide(color: scheme.outline, width: 2.0),
          ),
        ),
      ),

      // ── Bottom Sheet ────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NookTokens.kRadiusXl),
          ),
          side: BorderSide(color: scheme.outline, width: 2.0),
        ),
        showDragHandle: true,
      ),

      // ── Dialog ──────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusXl),
          side: BorderSide(color: scheme.outline, width: 2.0),
        ),
      ),

      // ── Chips ───────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primary,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          fontSize: 12,
        ),
        side: BorderSide(color: scheme.outline, width: 2.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
        ),
      ),

      // ── Input Decoration ────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
          borderSide: BorderSide(color: scheme.outline, width: 2.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
          borderSide: BorderSide(color: scheme.outline, width: 2.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
          borderSide: BorderSide(color: scheme.outline, width: 3.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
          borderSide: BorderSide(color: scheme.error, width: 2.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
          borderSide: BorderSide(color: scheme.error, width: 3.0),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // ── ListTile ────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        textColor: scheme.onSurface,
        iconColor: scheme.onSurface,
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
          return scheme.surface;
        }),
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
        trackOutlineWidth: const WidgetStatePropertyAll(2.0),
      ),

      // ── Radio ───────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.outline;
        }),
      ),

      // ── Checkbox ────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surface;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 2.0),
      ),

      // ── Slider ──────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.2),
      ),

      // ── Divider ─────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 2.0,
        space: 2.0,
      ),

      // ── SnackBar ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outline, width: 2.0),
        ),
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
        indicatorColor: scheme.primary,
      ),

      // ── TabBar ──────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurface,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
      ),

      // ── PopupMenu ───────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
          side: BorderSide(color: scheme.outline, width: 2.0),
        ),
      ),
    );
  }

  /// Convenience builder for high-contrast light theme.
  static ThemeData buildLight({Locale? locale}) =>
      build(Brightness.light, locale: locale);

  /// Convenience builder for high-contrast dark theme.
  static ThemeData buildDark({Locale? locale}) =>
      build(Brightness.dark, locale: locale);
}
