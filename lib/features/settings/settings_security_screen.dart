import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/pin_provider.dart';
import '../../core/providers/screenshot_blocker_provider.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../features/security/pin_entry_screen.dart';

class SettingsSecurityScreen extends ConsumerWidget {
  const SettingsSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final gate = ref.watch(biometricGateProvider);
    final blocker = ref.watch(screenshotBlockerProvider);
    final pinProv = ref.watch(pinProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Security',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          DockSafeArea.bottomOf(context) + 72,
        ),
        children: [
          _buildGlassCard(
            scheme,
            child: SwitchListTile.adaptive(
              title: const Text(
                'Biometric Lock',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Secure vault with Face ID or fingerprint',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              secondary: HugeIcon(
                icon: HugeIcons.strokeRoundedFingerPrint,
                color: scheme.primary,
                size: 28,
              ),
              value: gate.enabled,
              activeThumbColor: scheme.primary,
              onChanged: (value) => unawaited(() async {
                unawaited(HapticFeedback.lightImpact());
                final gate = ref.read(biometricGateProvider);
                if (!value) {
                  gate.setEnabled(false);
                  return;
                }
                final enabled = await gate.enableWithVerification();
                if (!enabled && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Authentication is unavailable on this device.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }()),
            ),
          ),
          const SizedBox(height: 16),
          _buildGlassCard(
            scheme,
            child: SwitchListTile.adaptive(
              title: const Text(
                'Block Screenshots',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Prevent screen recording and captures',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              secondary: HugeIcon(
                icon: HugeIcons.strokeRoundedBlockGame,
                color: scheme.primary,
                size: 28,
              ),
              value: blocker.blocked,
              activeThumbColor: scheme.primary,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                ref.read(screenshotBlockerProvider).setBlocked(value);
              },
            ),
          ),
          if (gate.enabled) ...[
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'AUTO-LOCK TIMER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: scheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
            _buildGlassCard(
              scheme,
              child: Column(
                children: [
                  for (final duration in AutoLockDuration.values)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(biometricGateProvider)
                              .setAutoLockDuration(duration);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _labelFor(duration),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (gate.autoLockDuration == duration)
                                HugeIcon(
                                  icon:
                                      HugeIcons.strokeRoundedCheckmarkCircle01,
                                  color: scheme.primary,
                                  size: 22,
                                )
                              else
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedCircle,
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              'PIN FALLBACK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: scheme.primary.withValues(alpha: 0.8),
              ),
            ),
          ),
          _buildGlassCard(
            scheme,
            child: SwitchListTile.adaptive(
              title: const Text(
                'PIN Access',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                pinProv.enabled
                    ? 'PIN is set'
                    : 'Set a PIN as biometric fallback',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              secondary: HugeIcon(
                icon: pinProv.enabled
                    ? HugeIcons.strokeRoundedLock
                    : HugeIcons.strokeRoundedKey01,
                color: scheme.primary,
                size: 28,
              ),
              value: pinProv.enabled,
              activeThumbColor: scheme.primary,
              onChanged: (value) async {
                unawaited(HapticFeedback.lightImpact());
                if (value) {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const PinEntryScreen(isSetup: true),
                    ),
                  );
                  if (result != true) return;
                } else {
                  await ref.read(pinProvider).clearPin();
                }
              },
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildGlassCard(ColorScheme scheme, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          // Material keeps SwitchListTile ink splashes on top of the frosted
          // background (avoids the "ink splashes may be invisible" warning).
          child: Material(
            type: MaterialType.transparency,
            child: child,
          ),
        ),
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
