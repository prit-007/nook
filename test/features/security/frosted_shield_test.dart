import 'dart:async';

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
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedLock),
        findsNothing);
  });

  testWidgets('renders nothing when lock disabled', (tester) async {
    final gate = BiometricGate(authenticator: () async => true);
    await tester.pumpWidget(buildShield(gate));

    expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedLock),
        findsNothing);
  });

  testWidgets('shows blur shield when locked', (tester) async {
    // Use a Completer so the authenticator doesn't resolve instantly —
    // this keeps the shield visible long enough to assert against it,
    // and avoids the timer leak from Future.delayed.
    final completer = Completer<bool>();
    final gate = BiometricGate(authenticator: () => completer.future)
      ..setEnabled(true);
    await tester.pumpWidget(buildShield(gate));
    await tester.pump();

    expect(find.byType(FrostedShield), findsOneWidget);
    expect(find.text('nook. is locked'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsWidgets);

    // Complete to avoid timer leak.
    completer.complete(true);
    await tester.pump();
  });

  testWidgets('successful auth focuses the view', (tester) async {
    final gate = BiometricGate(authenticator: () async => true)
      ..setEnabled(true);
    await tester.pumpWidget(buildShield(gate));
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(gate.isLocked, isFalse);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('failed auth keeps the shield', (tester) async {
    final gate = BiometricGate(authenticator: () async => false)
      ..setEnabled(true);
    await tester.pumpWidget(buildShield(gate));
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 600));

    expect(gate.isLocked, isTrue);
    expect(find.byType(FrostedShield), findsOneWidget);
    expect(find.text('Authentication failed'), findsOneWidget);
  });
}
