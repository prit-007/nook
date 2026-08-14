import 'dart:ui';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/pin_provider.dart';
import 'pin_entry_screen.dart';

/// "Frosted Shield" — maximum-strength blur veil over the live vault.
///
/// The underlying screen renders instantly but is trapped beneath a strong
/// [BackdropFilter]. On successful auth the blur animates down to sigma 0,
/// letting the notes snap into focus like a camera lens.
///
/// Uses a scrollable, constrained layout so it never overflows on extreme
/// aspect ratios.
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
      if (mounted) setState(() => _error = 'Authentication failed.');
      return;
    }
    setState(() => _error = null);
    setState(() => _hasUnlocked = true);
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
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: scheme.surface.withValues(alpha: 0.8),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: _FrostedShieldButton(
                          enabled: !gate.isAuthenticating,
                          onTap: _unlock,
                          error: _error,
                        ),
                      ),
                    ),
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

class _FrostedShieldButton extends StatelessWidget {
  const _FrostedShieldButton({
    required this.enabled,
    required this.onTap,
    this.error,
  });

  final bool enabled;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.shield, size: 56, color: scheme.primary),
                const SizedBox(height: 24),
                const Text(
                  'Vault Locked',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  defaultTargetPlatform == TargetPlatform.windows
                      ? 'Use Windows Hello to continue'
                      : 'Tap to unlock via biometrics',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 24),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.error,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Consumer(
          builder: (context, ref, _) {
            final pinProv = ref.watch(pinProvider);
            if (!pinProv.enabled) return const SizedBox.shrink();
            return OutlinedButton.icon(
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
              icon: const Icon(LucideIcons.keyRound),
              label: const Text('Use PIN'),
            );
          },
        ),
      ],
    );
  }
}
