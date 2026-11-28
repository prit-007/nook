import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/nook_tokens.dart';

/// Attentive time-of-day greeting and live vault summary banner.
class VaultGreetingBanner extends StatelessWidget {
  const VaultGreetingBanner({
    super.key,
    this.now,
    required this.noteCount,
    required this.openTaskCount,
  });

  final DateTime? now;
  final int noteCount;
  final int openTaskCount;

  String _greetingFor(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Late-night thoughts';
  }

  String _summaryText() {
    if (noteCount == 0 && openTaskCount == 0) {
      return 'Quiet vault — ready for your first thought';
    }
    final noteLabel = '$noteCount note${noteCount == 1 ? '' : 's'}';
    final taskLabel =
        '$openTaskCount open task${openTaskCount == 1 ? '' : 's'}';
    return '$noteLabel • $taskLabel';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = now ?? DateTime.now();
    final greeting = _greetingFor(current);
    final summary = _summaryText();

    return AnimatedSwitcher(
      duration: AppMotion.standard,
      switchInCurve: AppMotion.emphasizedDecelerate,
      switchOutCurve: AppMotion.emphasizedAccelerate,
      child: Container(
        key: ValueKey('$greeting-$summary'),
        padding: const EdgeInsets.symmetric(
          horizontal: NookTokens.kSpacingLg,
          vertical: NookTokens.kSpacingMd,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(NookTokens.kSpacingSm),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(NookTokens.kRadiusSm),
              ),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedSparkles,
                size: 20,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: NookTokens.kSpacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: NookTokens.kFontFloor,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
