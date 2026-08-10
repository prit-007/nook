import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_provider.dart';
import '../../core/providers/pin_provider.dart';
import '../../core/providers/theme_provider.dart';
import 'pin_entry_screen.dart';

/// Biometric lock screen per prompt #10.
/// Soft gradient background, frosted illustration, fingerprint icon with pulse,
/// "Unlock to see your notes", "Use PIN instead".
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _authenticating = false;

  Future<void> _unlockWithBiometric() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final gate = ref.read(biometricGateProvider);
    final ok = await gate.unlock();
    if (ok && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seedColor = ref.watch(themePreferenceProvider).seedColor;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              seedColor.withValues(alpha: 0.3),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text(
                  'nook',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Spacer(flex: 3),
              GestureDetector(
                onTap: _unlockWithBiometric,
                behavior: HitTestBehavior.opaque,
                child: Semantics(
                  label: 'Authenticate with biometrics to unlock',
                  button: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.surface.withValues(alpha: 0.6),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.note_alt_outlined,
                              size: 80,
                              color: seedColor.withValues(alpha: 0.15),
                            ),
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.surface,
                                boxShadow: [
                                  BoxShadow(
                                    color: seedColor.withValues(alpha: 0.15),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.fingerprint,
                                size: 48,
                                color: seedColor,
                              ),
                            ),
                            ...List.generate(3, (i) {
                              return Container(
                                width: 96.0 + (i + 1) * 24,
                                height: 96.0 + (i + 1) * 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: seedColor.withValues(
                                      alpha: 0.1 - i * 0.03,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 2),
              Text(
                'Unlock to see your notes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Biometric authentication required',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 24),
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
                        Navigator.of(context).pop(true);
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
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
