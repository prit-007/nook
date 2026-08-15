import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../update_models.dart';
import '../update_provider.dart';

/// Compact glass banner shown at the top of Home when a newer nook release is
/// available. Dismissing it hides the banner until a newer release appears.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(updateStatusProvider);
    if (!status.hasUpdate) return const SizedBox.shrink();
    final info = status.available!;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openRelease(context, info),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.55),
                  scheme.tertiaryContainer.withValues(alpha: 0.35),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedDownload01,
                          color: scheme.onPrimary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update available',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'nook v${info.latestVersion} is ready to install.',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          unawaited(
                            ref.read(updateStatusProvider.notifier).dismiss(),
                          );
                        },
                        child: const Text('Later'),
                      ),
                      FilledButton(
                        onPressed: () => _openRelease(context, info),
                        child: const Text('Update'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openRelease(BuildContext context, UpdateInfo info) async {
    await HapticFeedback.mediumImpact();
    final uri = Uri.parse(info.releaseUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
