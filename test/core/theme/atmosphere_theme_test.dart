import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/theme/atmosphere_theme.dart';
import 'package:nook/core/theme/high_contrast_theme.dart';

void main() {
  group('AtmosphereTheme', () {
    test('builds distinct ThemeData with accessible contrast for all presets',
        () {
      final surfaces = <Color>{};
      for (final preset in AtmospherePreset.values) {
        final theme = AtmosphereTheme.build(preset);
        final scheme = theme.colorScheme;
        surfaces.add(scheme.surface);

        final ratio = HighContrastTheme.contrastRatio(
          scheme.onSurface,
          scheme.surface,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: 'Preset ${preset.name} must maintain >= 4.5:1 contrast',
        );
      }
      expect(surfaces.length, greaterThanOrEqualTo(4));
    });
  });
}
