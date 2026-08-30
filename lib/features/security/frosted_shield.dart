import 'dart:ui';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/pin_provider.dart';
import 'pin_entry_screen.dart';

/// "Frosted Shield" — maximum-strength blur veil over the live vault.
///
/// The underlying screen renders instantly but is trapped beneath a strong
/// [BackdropFilter]. On successful auth the blur animates down to sigma 0,
/// letting the notes snap into focus like a camera lens.
///
/// Automatically triggers the biometric prompt the moment the shield appears,
/// identical to WhatsApp's App Lock behavior.
class FrostedShield extends ConsumerStatefulWidget {
  const FrostedShield({super.key});

  @override
  ConsumerState<FrostedShield> createState() => _FrostedShieldState();
}

class _FrostedShieldState extends ConsumerState<FrostedShield>
    with TickerProviderStateMixin {
  late final AnimationController _focusController;
  late final Animation<double> _blur;

  bool _hasUnlocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _blur = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _focusController, curve: Curves.easeOutCubic),
    );

    // Auto-trigger biometric prompt on load, identical to WhatsApp.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unlock();
    });
  }

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_hasUnlocked) return;
    unawaited(HapticFeedback.mediumImpact());

    final gate = ref.read(biometricGateProvider);
    final ok = await gate.unlock();

    if (!ok || !mounted) {
      if (mounted) setState(() => _error = 'Authentication failed');
      return;
    }
    setState(() {
      _error = null;
      _hasUnlocked = true;
    });
    await _focusController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gate = ref.watch(biometricGateProvider);

    if (!gate.isLocked || _hasUnlocked) return const SizedBox.shrink();

    return IgnorePointer(
      ignoring: gate.isAuthenticating,
      child: AnimatedBuilder(
        animation: _blur,
        builder: (context, child) {
          if (_blur.value <= 0.1) return const SizedBox.shrink();

          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _blur.value, sigmaY: _blur.value),
            child: Material(
              color: scheme.surface.withValues(alpha: 0.85),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedLock,
                        size: 64,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'nook. is locked',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error ?? 'Unlock to view your secure notes',
                        style: TextStyle(
                          fontSize: 15,
                          color: _error != null
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                          fontWeight: _error != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (!gate.isAuthenticating)
                        FilledButton.tonal(
                          onPressed: _unlock,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 16),
                          ),
                          child: const Text('Unlock',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(height: 16),
                      Consumer(
                        builder: (context, ref, _) {
                          final pinProv = ref.watch(pinProvider);
                          if (!pinProv.enabled || gate.isAuthenticating) {
                            return const SizedBox.shrink();
                          }
                          return TextButton(
                            onPressed: () async {
                              final result =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                    builder: (_) => const PinEntryScreen()),
                              );
                              if (result == true && context.mounted) {
                                ref.read(biometricGateProvider).unlockWithPin();
                              }
                            },
                            child: const Text('Use PIN'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
