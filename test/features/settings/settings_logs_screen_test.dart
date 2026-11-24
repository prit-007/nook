import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/settings/settings_logs_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'logs_help_seen': true});
  });

  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: SettingsLogsScreen(),
      ),
    );
  }

  testWidgets('renders diagnostic logs screen and title', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Diagnostic Logs'), findsOneWidget);
  });

  testWidgets('help pill opens walkthrough overlay when tapped',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final helpButton = find.text('Guide');
    expect(helpButton, findsOneWidget);

    await tester.tap(helpButton);
    await tester.pumpAndSettle();

    expect(find.text('System Diagnostics'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('System Diagnostics'), findsNothing);
  });
}
