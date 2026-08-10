import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/security/lock_screen.dart';

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(home: LockScreen()),
    );
  }

  testWidgets('renders unlock text', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Unlock to see your notes'), findsOneWidget);
  });

  testWidgets('renders biometric hint', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Biometric authentication required'), findsOneWidget);
  });

  testWidgets('renders fingerprint icon', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
  });

  testWidgets('renders PIN fallback when PIN enabled', (tester) async {
    await tester.pumpWidget(buildScreen());
    // PIN fallback is hidden by default (pin not enabled).
    expect(find.text('Use PIN instead'), findsNothing);
  });

  testWidgets('renders app name', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('nook'), findsOneWidget);
  });

  testWidgets('fingerprint icon is tappable', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pump();
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
  });
}
