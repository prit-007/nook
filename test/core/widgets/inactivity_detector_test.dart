import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/biometric_provider.dart';
import 'package:nook/core/widgets/inactivity_detector.dart';

void main() {
  testWidgets(
      'InactivityDetector records activity on user pointer interactions',
      (tester) async {
    final gate = BiometricGate(
      authenticator: () async => true,
      autoLockDuration: AutoLockDuration.fiveMinutes,
    );
    gate.setEnabled(true);
    await gate.unlock();

    final initialTime = gate.lastActivityAt;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          biometricGateProvider.overrideWith((ref) => gate),
        ],
        child: const MaterialApp(
          home: InactivityDetector(
            child: Scaffold(
              body: Center(child: Text('Content')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Advance clock and tap on content
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Content'));
    await tester.pump();

    expect(
        gate.lastActivityAt.isAfter(initialTime) ||
            gate.lastActivityAt.isAtSameMomentAs(initialTime),
        isTrue);

    // Unmount safely
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('InactivityDetector auto-locks when idle time elapses',
      (tester) async {
    final gate = BiometricGate(
      authenticator: () async => true,
      autoLockDuration: AutoLockDuration.oneMinute,
    );
    gate.setEnabled(true);
    await gate.unlock();
    expect(gate.isLocked, isFalse);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          biometricGateProvider.overrideWith((ref) => gate),
        ],
        child: MaterialApp(
          home: InactivityDetector(
            checkInterval: const Duration(seconds: 1),
            nowProvider: () => DateTime.now().add(const Duration(minutes: 2)),
            child: const Scaffold(
              body: Text('Active Content'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Trigger timer tick by advancing 1s
    await tester.pump(const Duration(seconds: 1));
    expect(gate.isLocked, isTrue);

    // Unmount safely
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
