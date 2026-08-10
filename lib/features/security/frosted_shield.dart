import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/pin_provider.dart';
import '../../core/providers/theme_provider.dart';
import 'pin_entry_screen.dart';

/// "Frosted Shield" — maximum-strength blur veil over the live vault.
///
/// The underlying screen renders instantly but is trapped beneath a strong
/// [BackdropFilter]. On successful auth the blur animates down to sigma 0,
/// letting the notes snap into focus like a camera lens.
class FrostedShield extends ConsumerStatefulWidget {
  const FrostedShield({super.key});

  @override
  ConsumerState<FrostedShield> createState() => _FrostedShieldState();
}

class _FrostedShieldState extends ConsumerState<FrostedShield>
    with TickerProviderStateMixin {
  late final AnimationController _focusController;
  late final Animation<double> _blur;

  late final AnimationController _pulseController;
  late final Animation<double> _pulse;

  bool _hasUnlocked = false;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _blur = Tween<double>(begin: 40, end: 0).animate(
        CurvedAnimation(parent: _focusController, curve: Curves.easeOut));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _focusController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_hasUnlocked) return;
    // ignore: unawaited_futures
    HapticFeedback.mediumImpact();
    final gate = ref.read(biometricGateProvider);
    final ok = await gate.unlock();
    if (!ok || !mounted) return;
    setState(() => _hasUnlocked = true);
    await _focusController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gate = ref.watch(biometricGateProvider);
    final seedColor = ref.watch(themePreferenceProvider).seedColor;

    if (!gate.isLocked || _hasUnlocked) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      ignoring: gate.isAuthenticating,
      child: AnimatedBuilder(
        animation: _blur,
        builder: (context, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _blur.value, sigmaY: _blur.value),
            child: Container(
              color: scheme.surface.withValues(alpha: 0.45),
              child: Center(
                child: _FrostedShieldButton(
                  enabled: !gate.isAuthenticating,
                  onTap: _unlock,
                  seed: seedColor,
                  pulse: _pulse,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FrostedShieldButton extends StatelessWidget {
  const _FrostedShieldButton({
    required this.enabled,
    required this.onTap,
    required this.seed,
    required this.pulse,
  });

  final bool enabled;
  final VoidCallback onTap;
  final Color seed;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: pulse,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface.withValues(alpha: 0.6),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: seed.withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ...List.generate(3, (i) {
                      return Container(
                        width: 120.0 + (i + 1) * 28,
                        height: 120.0 + (i + 1) * 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: seed.withValues(alpha: 0.35 - i * 0.1),
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                    Icon(Icons.fingerprint, size: 64, color: seed),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Unlock to see your notes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Touch the fingerprint to authenticate',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            // PIN fallback
            Consumer(
              builder: (context, ref, _) {
                final pinProv = ref.watch(pinProvider);
                if (!pinProv.enabled) return const SizedBox.shrink();
                return TextButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const PinEntryScreen(),
                      ),
                    );
                    if (result == true && context.mounted) {
                      ref.read(biometricGateProvider).unlockWithPin();
                    }
                  },
                  child: Text(
                    'Use PIN instead',
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
