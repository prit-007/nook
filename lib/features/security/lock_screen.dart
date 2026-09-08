import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/pin_provider.dart';
import '../../core/providers/talker_provider.dart';
import 'pin_entry_screen.dart';

/// Dedicated lock screen with automatic biometric prompt.
///
/// Uses a clean, minimalist layout — no bordered containers, just
/// typography and a centered fingerprint icon. Automatically triggers
/// biometric authentication the moment the screen appears.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unlockWithBiometric();
    });
  }

  Future<void> _unlockWithBiometric() async {
    if (_authenticating) return;
    nookLog(NookLogKey.security, 'Lock screen shown', LogLevel.info);
    setState(() => _authenticating = true);

    final gate = ref.read(biometricGateProvider);
    final ok = await gate.unlock();

    if (ok && mounted) {
      unawaited(HapticFeedback.lightImpact());
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedFingerPrint,
                size: 72,
                color: scheme.primary,
              ),
              const SizedBox(height: 32),
              const Text(
                'nook. is locked',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Authentication required to continue',
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),
              if (!_authenticating)
                FilledButton.tonal(
                  onPressed: _unlockWithBiometric,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 16),
                  ),
                  child: const Text('Unlock',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final pinProv = ref.watch(pinProvider);
                  if (!pinProv.enabled || _authenticating) {
                    return const SizedBox.shrink();
                  }
                  return TextButton(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) => const PinEntryScreen()),
                      );
                      if (result == true && context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: const Text('Use PIN instead'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
