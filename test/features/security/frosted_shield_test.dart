import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/biometric_provider.dart';
import 'package:nook/features/security/frosted_shield.dart';

void main() {
  Widget buildShield(BiometricGate gate) {
    return ProviderScope(
      overrides: [biometricGateProvider.overrideWith((ref) => gate)],
      child: MaterialApp(
        home: const Scaffold(body: SizedBox.expand()),
        builder: (context, child) => Stack(
          children: [child!, const FrostedShield()],
        ),
      ),
    );
  }

  testWidgets('renders nothing when unlocked', (tester) async {
    final gate = BiometricGate(authenticator: () async => true);
    await tester.pumpWidget(buildShield(gate));

    expect(find.byIcon(Icons.fingerprint), findsNothing);
  });

  testWidgets('renders nothing when lock disabled', (tester) async {
    final gate = BiometricGate(authenticator: () async => true);
    await tester.pumpWidget(buildShield(gate));

    expect(find.byIcon(Icons.fingerprint), findsNothing);
  });

  testWidgets('shows blur shield and fingerprint when locked', (tester) async {
    final gate = BiometricGate(authenticator: () async => true)
      ..setEnabled(true);
    await tester.pumpWidget(buildShield(gate));
    await tester.pump();

    expect(find.byType(FrostedShield), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    expect(find.text('Unlock to see your notes'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
  });

  testWidgets('successful auth focuses the view', (tester) async {
    final gate = BiometricGate(authenticator: () async => true)
      ..setEnabled(true);
    await tester.pumpWidget(buildShield(gate));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.fingerprint));
    // Blur animates 40 -> 0 over 400ms.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(gate.isLocked, isFalse);
    expect(find.byIcon(Icons.fingerprint), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('failed auth keeps the shield', (tester) async {
    final gate = BiometricGate(authenticator: () async => false)
      ..setEnabled(true);
    await tester.pumpWidget(buildShield(gate));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.fingerprint));
    await tester.pump();

    expect(gate.isLocked, isTrue);
    expect(find.byType(FrostedShield), findsOneWidget);
  });
}
