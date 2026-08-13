import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/theme/app_theme.dart';

void main() {
  group('buildDarkTheme', () {
    test('returns dark theme with correct brightness', () {
      final theme = buildDarkTheme(Colors.blue);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('scaffoldBackgroundColor matches surface', () {
      final theme = buildDarkTheme(Colors.green);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });

    test('defaults to non-black surface when amoled is false', () {
      final theme = buildDarkTheme(Colors.blue);
      expect(theme.colorScheme.surface, isNot(kAmoledSurface));
    });
  });

  group('buildDarkTheme(amoled)', () {
    test('uses pure-black surface', () {
      final theme = buildDarkTheme(Colors.blue, amoled: true);
      expect(theme.colorScheme.surface, const Color(0xFF000000));
    });

    test('keeps dark brightness', () {
      final theme = buildDarkTheme(Colors.blue, amoled: true);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('scaffold background is pure black', () {
      final theme = buildDarkTheme(Colors.green, amoled: true);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
    });

    test('preserves seed-derived primary/secondary/tertiary hues', () {
      final base = buildDarkTheme(Colors.orange);
      final amoled = buildDarkTheme(Colors.orange, amoled: true);
      // Hues must survive the AMOLED surface override.
      expect(amoled.colorScheme.primary, base.colorScheme.primary);
      expect(amoled.colorScheme.secondary, base.colorScheme.secondary);
      expect(amoled.colorScheme.tertiary, base.colorScheme.tertiary);
    });

    test('elevated components use solid surfaces and transparent tint', () {
      final theme = buildDarkTheme(Colors.blue, amoled: true);

      // Cards: solid near-black fill, no M3 elevation tint wash.
      expect(
        theme.cardTheme.color,
        theme.colorScheme.surfaceContainerHigh,
      );
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);

      // Dialogs / sheets / menus also transparent-tinted.
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
      expect(theme.popupMenuTheme.surfaceTintColor, Colors.transparent);
      expect(theme.navigationBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);

      // Chips and inputs switch to solid fills.
      expect(
          theme.chipTheme.backgroundColor, theme.colorScheme.surfaceContainer);
      expect(
        theme.inputDecorationTheme.fillColor,
        theme.colorScheme.surfaceContainer,
      );

      // SnackBar is inverted to read on black.
      expect(theme.snackBarTheme.backgroundColor, isNot(Colors.transparent));
      expect(
        theme.snackBarTheme.backgroundColor,
        theme.colorScheme.surfaceContainerHigh,
      );
    });

    test('non-AMOLED components keep default tint behavior', () {
      final theme = buildDarkTheme(Colors.blue);
      expect(theme.cardTheme.surfaceTintColor, isNull);
      expect(theme.appBarTheme.surfaceTintColor, isNull);
      expect(theme.popupMenuTheme.surfaceTintColor, isNull);
    });
  });

  group('applyAmoledSurfaces', () {
    test('overrides all neutral surface roles to the AMOLED ramp', () {
      final base = ColorScheme.fromSeed(
        seedColor: Colors.purple,
        brightness: Brightness.dark,
      );
      final amoled = applyAmoledSurfaces(base);

      expect(amoled.surface, kAmoledSurface);
      expect(amoled.surfaceDim, kAmoledSurfaceDim);
      expect(amoled.surfaceBright, kAmoledSurfaceBright);
      expect(amoled.surfaceContainerLowest, kAmoledSurfaceContainerLowest);
      expect(amoled.surfaceContainerLow, kAmoledSurfaceContainerLow);
      expect(amoled.surfaceContainer, kAmoledSurfaceContainer);
      expect(amoled.surfaceContainerHigh, kAmoledSurfaceContainerHigh);
      expect(amoled.surfaceContainerHighest, kAmoledSurfaceContainerHighest);
    });

    test('preserves seed-derived colors', () {
      final base = ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      );
      final amoled = applyAmoledSurfaces(base);

      expect(amoled.primary, base.primary);
      expect(amoled.secondary, base.secondary);
      expect(amoled.tertiary, base.tertiary);
      expect(amoled.onSurface, base.onSurface);
    });
  });

  group('buildLightTheme', () {
    test('returns light theme with correct brightness', () {
      final theme = buildLightTheme(Colors.teal);
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('light theme is never AMOLED', () {
      final theme = buildLightTheme(Colors.teal);
      expect(theme.colorScheme.surface, isNot(kAmoledSurface));
      expect(theme.cardTheme.surfaceTintColor, isNull);
    });
  });

  group('_buildTheme', () {
    test('themes NavigationRail for dark mode', () {
      final theme = buildDarkTheme(Colors.blue);
      final navRail = theme.navigationRailTheme;
      expect(navRail.backgroundColor, theme.colorScheme.surface);
      expect(navRail.indicatorColor, theme.colorScheme.primaryContainer);
    });

    test('themes TabBar', () {
      final theme = buildDarkTheme(Colors.red);
      final tabBar = theme.tabBarTheme;
      expect(tabBar.labelColor, theme.colorScheme.primary);
      expect(tabBar.indicatorColor, theme.colorScheme.primary);
    });

    test('themes PopupMenu', () {
      final theme = buildDarkTheme(Colors.green);
      final popup = theme.popupMenuTheme;
      expect(popup.color, theme.colorScheme.surfaceContainerHigh);
    });
  });
}
