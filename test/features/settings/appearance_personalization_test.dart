import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/note_type_preset_provider.dart';
import 'package:nook/core/providers/theme_provider.dart';
import 'package:nook/core/theme/atmosphere_theme.dart';
import 'package:nook/features/settings/settings_appearance_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsAppearanceScreen personalizations', () {
    testWidgets('displays Atmosphere presets and persists selection',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themePref = await ThemePreference.load();
      final presetStore = await NoteTypePresetStore.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themePreferenceProvider.overrideWith((_) => themePref),
            noteTypePresetProvider.overrideWith((_) => presetStore),
          ],
          child: const MaterialApp(
            home: SettingsAppearanceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atmosphere'), findsOneWidget);
      expect(find.text('Warm Sepia Paper'), findsOneWidget);
      expect(find.text('Note Type Defaults'), findsOneWidget);

      await tester.ensureVisible(find.text('Warm Sepia Paper'));
      await tester.tap(find.text('Warm Sepia Paper'));
      await tester.pumpAndSettle();

      expect(themePref.atmosphere, AtmospherePreset.warmSepia);
    });
  });
}
