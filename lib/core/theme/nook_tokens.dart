import 'package:flutter/material.dart';

/// Centralized design tokens for Nook adhering to Material 3 principles and
/// Nook's editorial identity.
///
/// Provides consistent spacing, standard corner radii, accessible touch/text
/// floors, and semantic opacity / color roles across the app.
@immutable
class NookTokens extends ThemeExtension<NookTokens> {
  // ── Static Token Constants (usable in ThemeData and const contexts) ────
  static const double kSpacingXs = 4.0;
  static const double kSpacingSm = 8.0;
  static const double kSpacingMd = 12.0;
  static const double kSpacingLg = 16.0;
  static const double kSpacingXl = 24.0;
  static const double kSpacingXxl = 32.0;

  static const double kRadiusXs = 8.0;
  static const double kRadiusSm = 12.0;
  static const double kRadiusMd = 20.0;
  static const double kRadiusLg = 24.0;
  static const double kRadiusXl = 28.0;
  static const double kRadiusXxl = 32.0;
  static const double kRadiusPill = 999.0;

  static const double kMinTapTarget = 48.0;
  static const double kFontFloor = 12.0;
  static const double kEyebrowSize = 12.0;
  static const double kGlassOpacity = 0.85;
  static const double kFlashOverlayLightOpacity = 0.4;
  static const double kFlashOverlayDarkOpacity = 0.2;

  const NookTokens({
    // Spacing
    this.spacingXs = kSpacingXs,
    this.spacingSm = kSpacingSm,
    this.spacingMd = kSpacingMd,
    this.spacingLg = kSpacingLg,
    this.spacingXl = kSpacingXl,
    this.spacingXxl = kSpacingXxl,

    // Radii
    this.radiusXs = kRadiusXs,
    this.radiusSm = kRadiusSm,
    this.radiusMd = kRadiusMd,
    this.radiusLg = kRadiusLg,
    this.radiusXl = kRadiusXl,
    this.radiusXxl = kRadiusXxl,
    this.radiusPill = kRadiusPill,

    // Accessibility floors
    this.minTapTarget = kMinTapTarget,
    this.fontFloor = kFontFloor,
    this.eyebrowSize = kEyebrowSize,
    this.glassOpacity = kGlassOpacity,
    this.flashOverlayLightOpacity = kFlashOverlayLightOpacity,
    this.flashOverlayDarkOpacity = kFlashOverlayDarkOpacity,

    // Semantic colors / opacity roles
    required this.hairline,
    required this.borderSubtle,
    required this.surfaceTintSubtle,
    required this.scrim,
    required this.dockSurface,
    required this.dockBorder,
    required this.dockShadow,
    required this.glassSurface,
  });

  // ── Spacing Tokens ──────────────────────────────────────────
  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;
  final double spacingXxl;

  // ── Radii Tokens ────────────────────────────────────────────
  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusXxl;
  final double radiusPill;

  BorderRadius get borderRadiusXs => BorderRadius.circular(radiusXs);
  BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
  BorderRadius get borderRadiusXxl => BorderRadius.circular(radiusXxl);
  BorderRadius get borderRadiusPill => BorderRadius.circular(radiusPill);

  // ── Accessibility Floors ────────────────────────────────────
  final double minTapTarget;
  final double fontFloor;
  final double eyebrowSize;
  final double glassOpacity;
  final double flashOverlayLightOpacity;
  final double flashOverlayDarkOpacity;

  // ── Semantic Opacity & Tint Roles ───────────────────────────
  final Color hairline;
  final Color borderSubtle;
  final Color surfaceTintSubtle;
  final Color scrim;
  final Color dockSurface;
  final Color dockBorder;
  final Color dockShadow;
  final Color glassSurface;

  /// Builds tokens derived from a [ColorScheme].
  factory NookTokens.fromScheme(ColorScheme scheme, {bool amoled = false}) {
    final isLight = scheme.brightness == Brightness.light;
    return NookTokens(
      hairline: scheme.outlineVariant.withValues(alpha: isLight ? 0.35 : 0.25),
      borderSubtle:
          scheme.outlineVariant.withValues(alpha: isLight ? 0.25 : 0.18),
      surfaceTintSubtle: scheme.primary.withValues(alpha: 0.12),
      scrim: Colors.black.withValues(alpha: 0.45),
      dockSurface: amoled
          ? scheme.surfaceContainerHigh
          : scheme.surfaceContainerHigh.withValues(alpha: 0.88),
      dockBorder:
          scheme.outlineVariant.withValues(alpha: isLight ? 0.25 : 0.18),
      dockShadow: scheme.shadow.withValues(alpha: isLight ? 0.08 : 0.2),
      glassSurface: Color.alphaBlend(
        isLight
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.black.withValues(alpha: 0.10),
        scheme.surface,
      ),
    );
  }

  /// Fallback tokens when no ThemeExtension is present.
  factory NookTokens.fallback() {
    return const NookTokens(
      hairline: Color(0x3379747E),
      borderSubtle: Color(0x2679747E),
      surfaceTintSubtle: Color(0x1F6750A4),
      scrim: Color(0x73000000),
      dockSurface: Color(0xDE2B2930),
      dockBorder: Color(0x2679747E),
      dockShadow: Color(0x14000000),
      glassSurface: Color(0x1AFFFFFF),
      glassOpacity: kGlassOpacity,
      flashOverlayLightOpacity: kFlashOverlayLightOpacity,
      flashOverlayDarkOpacity: kFlashOverlayDarkOpacity,
    );
  }

  @override
  ThemeExtension<NookTokens> copyWith({
    double? spacingXs,
    double? spacingSm,
    double? spacingMd,
    double? spacingLg,
    double? spacingXl,
    double? spacingXxl,
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusXxl,
    double? radiusPill,
    double? minTapTarget,
    double? fontFloor,
    double? eyebrowSize,
    double? glassOpacity,
    double? flashOverlayLightOpacity,
    double? flashOverlayDarkOpacity,
    Color? hairline,
    Color? borderSubtle,
    Color? surfaceTintSubtle,
    Color? scrim,
    Color? dockSurface,
    Color? dockBorder,
    Color? dockShadow,
    Color? glassSurface,
  }) {
    return NookTokens(
      spacingXs: spacingXs ?? this.spacingXs,
      spacingSm: spacingSm ?? this.spacingSm,
      spacingMd: spacingMd ?? this.spacingMd,
      spacingLg: spacingLg ?? this.spacingLg,
      spacingXl: spacingXl ?? this.spacingXl,
      spacingXxl: spacingXxl ?? this.spacingXxl,
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusXxl: radiusXxl ?? this.radiusXxl,
      radiusPill: radiusPill ?? this.radiusPill,
      minTapTarget: minTapTarget ?? this.minTapTarget,
      fontFloor: fontFloor ?? this.fontFloor,
      eyebrowSize: eyebrowSize ?? this.eyebrowSize,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      flashOverlayLightOpacity:
          flashOverlayLightOpacity ?? this.flashOverlayLightOpacity,
      flashOverlayDarkOpacity:
          flashOverlayDarkOpacity ?? this.flashOverlayDarkOpacity,
      hairline: hairline ?? this.hairline,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      surfaceTintSubtle: surfaceTintSubtle ?? this.surfaceTintSubtle,
      scrim: scrim ?? this.scrim,
      dockSurface: dockSurface ?? this.dockSurface,
      dockBorder: dockBorder ?? this.dockBorder,
      dockShadow: dockShadow ?? this.dockShadow,
      glassSurface: glassSurface ?? this.glassSurface,
    );
  }

  @override
  ThemeExtension<NookTokens> lerp(
    covariant ThemeExtension<NookTokens>? other,
    double t,
  ) {
    if (other is! NookTokens) return this;
    return NookTokens(
      spacingXs: _lerpDouble(spacingXs, other.spacingXs, t),
      spacingSm: _lerpDouble(spacingSm, other.spacingSm, t),
      spacingMd: _lerpDouble(spacingMd, other.spacingMd, t),
      spacingLg: _lerpDouble(spacingLg, other.spacingLg, t),
      spacingXl: _lerpDouble(spacingXl, other.spacingXl, t),
      spacingXxl: _lerpDouble(spacingXxl, other.spacingXxl, t),
      radiusXs: _lerpDouble(radiusXs, other.radiusXs, t),
      radiusSm: _lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: _lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: _lerpDouble(radiusLg, other.radiusLg, t),
      radiusXl: _lerpDouble(radiusXl, other.radiusXl, t),
      radiusXxl: _lerpDouble(radiusXxl, other.radiusXxl, t),
      radiusPill: _lerpDouble(radiusPill, other.radiusPill, t),
      minTapTarget: _lerpDouble(minTapTarget, other.minTapTarget, t),
      fontFloor: _lerpDouble(fontFloor, other.fontFloor, t),
      eyebrowSize: _lerpDouble(eyebrowSize, other.eyebrowSize, t),
      glassOpacity: _lerpDouble(glassOpacity, other.glassOpacity, t),
      flashOverlayLightOpacity: _lerpDouble(
          flashOverlayLightOpacity, other.flashOverlayLightOpacity, t),
      flashOverlayDarkOpacity: _lerpDouble(
          flashOverlayDarkOpacity, other.flashOverlayDarkOpacity, t),
      hairline: Color.lerp(hairline, other.hairline, t) ?? hairline,
      borderSubtle:
          Color.lerp(borderSubtle, other.borderSubtle, t) ?? borderSubtle,
      surfaceTintSubtle:
          Color.lerp(surfaceTintSubtle, other.surfaceTintSubtle, t) ??
              surfaceTintSubtle,
      scrim: Color.lerp(scrim, other.scrim, t) ?? scrim,
      dockSurface: Color.lerp(dockSurface, other.dockSurface, t) ?? dockSurface,
      dockBorder: Color.lerp(dockBorder, other.dockBorder, t) ?? dockBorder,
      dockShadow: Color.lerp(dockShadow, other.dockShadow, t) ?? dockShadow,
      glassSurface:
          Color.lerp(glassSurface, other.glassSurface, t) ?? glassSurface,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Convenience extension on [BuildContext] to access [NookTokens].
extension NookTokensContext on BuildContext {
  NookTokens get tokens =>
      Theme.of(this).extension<NookTokens>() ?? NookTokens.fallback();
}
