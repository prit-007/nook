import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/security/recovery_key_dialog.dart';
import 'package:nook/features/security/security_settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SecuritySettingsDialog', () {
    testWidgets('renders dialog with security quick actions and recovery key',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showSecuritySettingsDialog(context),
                  child: const Text('Open Security Settings'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Security Settings'));
      await tester.pumpAndSettle();

      expect(find.byType(SecuritySettingsDialog), findsOneWidget);
      expect(find.text('Security & Privacy'), findsOneWidget);
      expect(find.text('Biometric Lock'), findsOneWidget);
      expect(find.text('Backup Recovery Key'), findsOneWidget);
    });

    testWidgets(
        'tapping Backup Recovery Key from dialog opens RecoveryKeyDialog',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showSecuritySettingsDialog(context),
                  child: const Text('Open Security Settings'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Security Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Backup Recovery Key'));
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryKeyDialog), findsOneWidget);
    });
  });
}
