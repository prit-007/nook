import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/theme_provider.dart';
import 'package:nook/features/settings/settings_appearance_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget buildScreen({ThemePreference? preference}) {
    return ProviderScope(
      overrides: [
        if (preference != null)
          themePreferenceProvider.overrideWith((ref) => preference),
      ],
      child: const MaterialApp(home: SettingsAppearanceScreen()),
    );
  }

  testWidgets('renders AppBar with title', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('shows theme mode selector', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('THEME MODE'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('shows seed color section', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('SEED COLOR SIGNATURE'), findsOneWidget);
  });

  testWidgets('shows all 12 seed swatches', (tester) async {
    await tester.pumpWidget(buildScreen());
    // 12 NookColors.seeds entries
    final swatches = find.byType(GestureDetector);
    expect(swatches, findsAtLeastNWidgets(12));
  });

  testWidgets('shows reduce motion toggle', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('REDUCE MOTION'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('toggling reduce motion flips and persists the preference',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preference = await ThemePreference.load();
    await tester.pumpWidget(buildScreen(preference: preference));

    final switchFinder = find.byType(Switch);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(preference.reduceMotion, isTrue);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    final reloaded = await ThemePreference.load();
    expect(reloaded.reduceMotion, isTrue);
  });
}
