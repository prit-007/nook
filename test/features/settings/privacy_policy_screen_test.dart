import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/settings/settings_privacy_screen.dart';

void main() {
  Widget buildScreen() {
    return const MaterialApp(home: SettingsPrivacyScreen());
  }

  testWidgets('renders AppBar with title', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Privacy Policy'), findsWidgets);
  });

  testWidgets('explains local-first data handling', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('LOCAL-FIRST'), findsOneWidget);
    expect(find.textContaining('no data is collected'), findsOneWidget);
  });

  testWidgets('declares permissions honestly', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.scrollUntilVisible(find.text('Wi-Fi Sync'), 100);
    await tester.scrollUntilVisible(find.text('Biometric Lock'), 100);
    await tester.scrollUntilVisible(find.text('Storage & Backup'), 100);
    expect(find.text('Wi-Fi Sync'), findsOneWidget);
    expect(find.text('Biometric Lock'), findsOneWidget);
    expect(find.text('Storage & Backup'), findsOneWidget);
  });
}
