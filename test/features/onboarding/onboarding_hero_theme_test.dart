import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/theme_provider.dart';
import 'package:nook/core/providers/vault_password_provider.dart';
import 'package:nook/core/widgets/animated_squircle.dart';
import 'package:nook/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Onboarding welcome tour hero & live seed theme', () {
    testWidgets('renders Hero AnimatedSquircle emblem and AnimatedTheme',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themePref = await ThemePreference.load();
      final vaultPref = await VaultPasswordProvider.load();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themePreferenceProvider.overrideWith((_) => themePref),
            vaultPasswordProvider.overrideWith((_) => vaultPref),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Hero), findsWidgets);
      expect(find.byType(AnimatedSquircle), findsOneWidget);
      expect(find.byType(AnimatedTheme), findsWidgets);
    });
  });
}
