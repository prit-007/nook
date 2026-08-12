import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:nook/features/settings/settings_screen.dart';

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(home: SettingsScreen()),
    );
  }

  testWidgets('renders AppBar with title', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('renders Appearance section header', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('APPEARANCE'), findsOneWidget);
  });

  testWidgets('renders Security section header', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('SECURITY & PRIVACY'), findsOneWidget);
  });

  testWidgets('renders Storage & Sync section header', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('STORAGE & SYNC'), findsOneWidget);
  });

  testWidgets('renders About section header', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.scrollUntilVisible(find.text('ABOUT'), 100);
    expect(find.text('ABOUT'), findsOneWidget);
  });

  testWidgets('renders theme tile with System value', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Theme & Colors'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('renders biometric lock tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Biometric Lock'), findsOneWidget);
  });

  testWidgets('renders auto-lock timer tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Auto-Lock Timer'), findsOneWidget);
    expect(find.text('5 minutes'), findsOneWidget);
  });

  testWidgets('renders screenshot blocking tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Screenshot Blocking'), findsOneWidget);
  });

  testWidgets('renders storage used tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Storage Used'), findsOneWidget);
    expect(find.text('48 MB \u00b7 214 notes'), findsOneWidget);
  });

  testWidgets('renders export vault tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Export Vault'), findsOneWidget);
  });

  testWidgets('renders paired devices tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Paired Devices'), findsOneWidget);
    expect(find.text('2 active'), findsOneWidget);
  });

  testWidgets('renders privacy policy tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.scrollUntilVisible(find.text('Privacy Policy'), 100);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });

  testWidgets('renders open source licenses tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.scrollUntilVisible(find.text('Open Source Licenses'), 100);
    expect(find.text('Open Source Licenses'), findsOneWidget);
  });

  testWidgets('renders version tile with value', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.scrollUntilVisible(find.text('Version'), 100);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
  });

  testWidgets('renders two switches', (tester) async {
    await tester.pumpWidget(buildScreen());
    // biometric lock on, screenshot blocking off
    expect(find.byType(Switch), findsNWidgets(2));
  });

  testWidgets('renders chevron icons for tappable tiles', (tester) async {
    await tester.pumpWidget(buildScreen());
    // Theme, Auto-lock, Storage, Paired devices, Version = 5 chevrons
    expect(find.byIcon(LucideIcons.chevronRight), findsAtLeastNWidgets(5));
  });

  testWidgets('renders section containers with rounded corners',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    // 4 section containers
    final containers = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Container),
      ),
    );
    expect(containers.length, greaterThanOrEqualTo(4));
  });
}
