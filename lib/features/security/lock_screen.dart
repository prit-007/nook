import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/pin_provider.dart';
import '../../core/providers/talker_provider.dart';
import 'pin_entry_screen.dart';

/// Editorial biometric lock screen.
/// Uses `SliverFillRemaining` so the layout is unbreakable on any
/// aspect ratio — desktop, tablet, landscape, or tiny phone.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _authenticating = false;

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
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    // Editorial App Identity
                    const Text(
                      'nook.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),

                    const Spacer(),

                    // Constrained Identity Block
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _unlockWithBiometric,
                            child: Semantics(
                              label: 'Authenticate with biometrics',
                              button: true,
                              child: Container(
                                padding: const EdgeInsets.all(48),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.outlineVariant
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Icon(
                                  LucideIcons.fingerprint,
                                  size: 80,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          const Text(
                            'Secure Vault',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Authentication required to view notes.',
                            style: TextStyle(
                              fontSize: 15,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Consumer(
                            builder: (context, ref, _) {
                              final pinProv = ref.watch(pinProvider);
                              if (!pinProv.enabled) {
                                return const SizedBox.shrink();
                              }
                              return TextButton.icon(
                                onPressed: () async {
                                  final result =
                                      await Navigator.of(context).push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) => const PinEntryScreen(),
                                    ),
                                  );
                                  if (result == true && context.mounted) {
                                    Navigator.of(context).pop(true);
                                  }
                                },
                                icon: const Icon(LucideIcons.keyRound),
                                label: const Text(
                                  'Use PIN instead',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: scheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
