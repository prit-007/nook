import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/security/recovery_key_dialog.dart';
import 'package:nook/features/settings/settings_security_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: SettingsSecurityScreen(),
      ),
    );
  }

  group('SettingsSecurityScreen', () {
    testWidgets('renders security items and recovery key option',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Biometric Lock'), findsOneWidget);
      expect(find.text('Block Screenshots'), findsOneWidget);
      expect(find.text('PIN Access'), findsOneWidget);
      expect(find.text('Vault password'), findsWidgets);

      // Verify Recovery Key is present as a user-facing option
      await tester.scrollUntilVisible(find.text('Recovery Key'), 100);
      expect(find.text('Recovery Key'), findsOneWidget);
      expect(
        find.textContaining('24-word phrase'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Recovery Key opens RecoveryKeyDialog', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Recovery Key'), 100);
      await tester.tap(find.text('Recovery Key'));
      await tester.pumpAndSettle();

      expect(find.byType(RecoveryKeyDialog), findsOneWidget);
      expect(find.text('Vault Recovery Key'), findsOneWidget);
    });
  });
}
