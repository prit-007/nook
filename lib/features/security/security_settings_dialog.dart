import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/haptics/haptics.dart';
import '../../core/providers/biometric_provider.dart';
import '../../core/theme/nook_tokens.dart';
import 'recovery_key_dialog.dart';

/// Opens the [SecuritySettingsDialog].
Future<void> showSecuritySettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const SecuritySettingsDialog(),
  );
}

/// A compact, frosted dialog for quick access to vault security settings
/// and recovery key backup.
class SecuritySettingsDialog extends ConsumerWidget {
  const SecuritySettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final gate = ref.watch(biometricGateProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NookTokens.kRadiusXxl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(NookTokens.kRadiusXxl),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              NookTokens.kRadiusMd,
                            ),
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedShield01,
                              color: scheme.primary,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Security & Privacy',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Vault protection & recovery',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Biometric Lock Toggle
                    Material(
                      color: scheme.surface.withValues(alpha: 0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          NookTokens.kRadiusLg,
                        ),
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        secondary: HugeIcon(
                          icon: HugeIcons.strokeRoundedFingerPrint,
                          color: scheme.primary,
                          size: 24,
                        ),
                        title: const Text(
                          'Biometric Lock',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Lock vault with biometric sensor',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        value: gate.enabled,
                        activeThumbColor: scheme.primary,
                        onChanged: (val) async {
                          unawaited(AppHaptics.selection());
                          if (!val) {
                            ref.read(biometricGateProvider).setEnabled(false);
                          } else {
                            unawaited(
                              ref
                                  .read(biometricGateProvider)
                                  .enableWithVerification(),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Backup Recovery Key Action
                    Material(
                      color: scheme.surface.withValues(alpha: 0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          NookTokens.kRadiusLg,
                        ),
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: HugeIcon(
                          icon: HugeIcons.strokeRoundedKey01,
                          color: scheme.primary,
                          size: 24,
                        ),
                        title: const Text(
                          'Backup Recovery Key',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '24-word emergency recovery phrase',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: const HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 18,
                        ),
                        onTap: () {
                          unawaited(AppHaptics.medium());
                          unawaited(showRecoveryKeyDialog(context));
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Done Button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            NookTokens.kRadiusLg,
                          ),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
