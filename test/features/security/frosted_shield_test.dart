import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
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

    expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedShield01),
        findsNothing);
  });

  testWidgets('renders nothing when lock disabled', (tester) async {
    final gate = BiometricGate(authenticator: () async => true);
    await tester.pumpWidget(buildShield(gate));

    expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedShield01),
        findsNothing);
  });

  testWidgets('shows blur shield when locked', (tester) async {
    final gate = BiometricGate(authenticator: () async => true)
      ..setEnabled(true);
    await tester.pumpWidget(buildShield(gate));
    await tester.pump();

    expect(find.byType(FrostedShield), findsOneWidget);
    expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedShield01),
        findsOneWidget);
    expect(find.text('Vault Locked'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);
  });

  testWidgets('successful auth focuses the view', (tester) async {
    final gate = BiometricGate(authenticator: () async => true)
      ..setEnabled(true);
    await tester.pumpWidget(buildShield(gate));
    await tester.pump();

    await tester.tap(
      find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedShield01),
      warnIfMissed: false,
    );
    // Blur animates 40 -> 0 over 500ms.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(gate.isLocked, isFalse);
    expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedShield01),
        findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('failed auth keeps the shield', (tester) async {
    final gate = BiometricGate(authenticator: () async => false)
      ..setEnabled(true);
    await tester.pumpWidget(buildShield(gate));
    await tester.pump();

    await tester.tap(
      find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedShield01),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(gate.isLocked, isTrue);
    expect(find.byType(FrostedShield), findsOneWidget);
  });
}
