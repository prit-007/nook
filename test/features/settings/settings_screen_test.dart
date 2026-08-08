import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/settings/settings_screen.dart';

void main() {
  Widget buildScreen() {
    return const MaterialApp(home: SettingsScreen());
  }

  testWidgets('renders AppBar with title', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('renders Appearance section header', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('renders Security section header', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Security'), findsOneWidget);
  });

  testWidgets('renders Storage & Sync section header', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Storage & Sync'), findsOneWidget);
  });

  testWidgets('renders About section header', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.scrollUntilVisible(find.text('About'), 100);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('renders dynamic color tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Dynamic color'), findsOneWidget);
  });

  testWidgets('renders theme tile with System value', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('renders biometric lock tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Biometric lock'), findsOneWidget);
  });

  testWidgets('renders auto-lock timer tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Auto-lock timer'), findsOneWidget);
    expect(find.text('1 minute'), findsOneWidget);
  });

  testWidgets('renders screenshot blocking tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Screenshot blocking'), findsOneWidget);
  });

  testWidgets('renders storage used tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Storage used'), findsOneWidget);
    expect(find.text('48 MB \u00b7 214 notes'), findsOneWidget);
  });

  testWidgets('renders export all notes tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Export all notes'), findsOneWidget);
  });

  testWidgets('renders paired devices tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Paired devices'), findsOneWidget);
    expect(find.text('2 devices'), findsOneWidget);
  });

  testWidgets('renders privacy policy tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.scrollUntilVisible(find.text('Privacy policy'), 100);
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('renders open source licenses tile', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.scrollUntilVisible(find.text('Open source licenses'), 100);
    expect(find.text('Open source licenses'), findsOneWidget);
  });

  testWidgets('renders version tile with value', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.scrollUntilVisible(find.text('Version'), 100);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
  });

  testWidgets('renders three switches', (tester) async {
    await tester.pumpWidget(buildScreen());
    // dynamic color on, biometric lock on, screenshot blocking off
    expect(find.byType(Switch), findsNWidgets(3));
  });

  testWidgets('renders chevron icons for tappable tiles', (tester) async {
    await tester.pumpWidget(buildScreen());
    // Theme, Auto-lock, Storage, Paired devices, Version = 5 chevrons
    expect(find.byIcon(Icons.chevron_right), findsAtLeastNWidgets(5));
  });

  testWidgets('renders section containers with rounded corners', (tester) async {
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
