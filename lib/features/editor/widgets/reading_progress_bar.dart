import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/nook_tokens.dart';

/// Subtle seed-tinted reading progress bar with live word count and
/// estimated read-time indicator.
class ReadingProgressBar extends StatelessWidget {
  const ReadingProgressBar({
    super.key,
    required this.plainText,
    this.scrollProgress = 0.0,
    this.wordsPerMinute = 200,
  });

  final String plainText;
  final double scrollProgress;
  final int wordsPerMinute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = plainText.trim();
    final wordCount = trimmed.isEmpty
        ? 0
        : trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final minutes = wordCount == 0 ? 0 : (wordCount / wordsPerMinute).ceil();
    final clamped = scrollProgress.clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: clamped),
          duration: AppMotion.short4,
          curve: AppMotion.standardEasing,
          builder: (context, value, _) {
            return LinearProgressIndicator(
              value: value,
              minHeight: 2.5,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NookTokens.kSpacingLg,
            vertical: NookTokens.kSpacingXs,
          ),
          child: Text(
            '$wordCount word${wordCount == 1 ? '' : 's'} • $minutes min read',
            style: TextStyle(
              fontSize: NookTokens.kFontFloor,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
