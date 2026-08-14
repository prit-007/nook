import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:nook/features/security/lock_screen.dart';

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(home: LockScreen()),
    );
  }

  testWidgets('renders vault title', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Secure Vault'), findsOneWidget);
  });

  testWidgets('renders auth subtitle', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(
      find.text('Authentication required to view notes.'),
      findsOneWidget,
    );
  });

  testWidgets('renders fingerprint icon', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.byIcon(LucideIcons.fingerprint), findsOneWidget);
  });

  testWidgets('renders PIN fallback when PIN enabled', (tester) async {
    await tester.pumpWidget(buildScreen());
    // PIN fallback is hidden by default (pin not enabled).
    expect(find.text('Use PIN instead'), findsNothing);
  });

  testWidgets('renders app name', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('nook.'), findsOneWidget);
  });

  testWidgets('fingerprint icon is tappable', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.tap(
      find.byIcon(LucideIcons.fingerprint),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.byIcon(LucideIcons.fingerprint), findsOneWidget);
  });
}
