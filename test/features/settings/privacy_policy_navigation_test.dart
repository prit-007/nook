import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/settings/settings_privacy_screen.dart';
import 'package:nook/features/settings/settings_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'nook',
      packageName: 'com.devparadise.nook',
      version: '0.9.6',
      buildNumber: '6',
      buildSignature: '',
      installerStore: null,
    );
  });

  GoRouter createTestRouter() {
    return GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'privacy',
              builder: (_, __) => const SettingsPrivacyScreen(),
            ),
          ],
        ),
      ],
    );
  }

  testWidgets('Privacy policy is accessible from Settings via tap navigation',
      (tester) async {
    final router = createTestRouter();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);

    // Scroll until the Privacy Policy tile is visible and tap it
    final privacyTile = find.text('Privacy Policy');
    await tester.scrollUntilVisible(privacyTile, 100);
    await tester.ensureVisible(privacyTile);
    await tester.pumpAndSettle();
    expect(privacyTile, findsOneWidget);

    await tester.tap(privacyTile, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Verify SettingsPrivacyScreen sections are reachable
    expect(find.text('Local-first'), findsOneWidget);
    expect(find.text('Permissions'), findsOneWidget);
    expect(find.text('Wi-Fi Sync'), findsOneWidget);
    expect(find.text('Biometric Lock'), findsOneWidget);
    expect(find.text('Storage & Backup'), findsOneWidget);

    await tester.scrollUntilVisible(
        find.text('Reminders & Notifications'), 100);
    expect(find.text('Reminders & Notifications'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Camera'), 100);
    expect(find.text('Camera'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Your control'), 100);
    expect(find.text('Your control'), findsOneWidget);
  });
}
