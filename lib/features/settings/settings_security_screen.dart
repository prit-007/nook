import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/screenshot_blocker_provider.dart';

class SettingsSecurityScreen extends ConsumerWidget {
  const SettingsSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final gate = ref.watch(biometricGateProvider);
    final blocker = ref.watch(screenshotBlockerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Biometric lock ──
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              title: const Text('Biometric lock'),
              subtitle:
                  const Text('Lock your vault with Face ID or fingerprint'),
              secondary: Icon(
                Icons.fingerprint,
                color: scheme.primary,
              ),
              value: gate.enabled,
              onChanged: (value) =>
                  ref.read(biometricGateProvider).setEnabled(value),
            ),
          ),

          const SizedBox(height: 12),

          // ── Screenshot blocking ──
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              title: const Text('Block screenshots'),
              subtitle: const Text(
                'Prevent screen recording and screenshots',
              ),
              secondary: Icon(
                Icons.screen_lock_portrait_rounded,
                color: scheme.primary,
              ),
              value: blocker.blocked,
              onChanged: (value) =>
                  ref.read(screenshotBlockerProvider).setBlocked(value),
            ),
          ),

          if (gate.enabled) ...[
            const SizedBox(height: 24),

            // ── Auto-lock timer ──
            Text(
              'AUTO-LOCK TIMER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: RadioGroup<AutoLockTile>(
                groupValue: AutoLockTile(gate.autoLockDuration),
                onChanged: (tile) {
                  if (tile != null) {
                    ref
                        .read(biometricGateProvider)
                        .setAutoLockDuration(tile.duration);
                  }
                },
                child: Column(
                  children: [
                    for (final duration in AutoLockDuration.values)
                      RadioListTile<AutoLockTile>(
                        title: Text(_labelFor(duration)),
                        value: AutoLockTile(duration),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _labelFor(AutoLockDuration d) => switch (d) {
        AutoLockDuration.immediately => 'Immediately',
        AutoLockDuration.oneMinute => 'After 1 minute',
        AutoLockDuration.fiveMinutes => 'After 5 minutes',
        AutoLockDuration.fifteenMinutes => 'After 15 minutes',
        AutoLockDuration.never => 'Never',
      };
}

/// Wrapper so RadioListTile can use value equality on the enum.
class AutoLockTile {
  const AutoLockTile(this.duration);
  final AutoLockDuration duration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutoLockTile && duration == other.duration;

  @override
  int get hashCode => duration.hashCode;
}
