import 'package:flutter/material.dart';
import 'package:nook/core/theme/design_tokens.dart';

/// A small tag pill displayed on note cards for view-only purposes.
class CardTagPill extends StatelessWidget {
  const CardTagPill({
    super.key,
    required this.label,
    required this.colorSeed,
  });

  final String label;
  final String colorSeed;

  @override
  Widget build(BuildContext context) {
    final tagColor = NookColors.parseHex(colorSeed);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 24,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tagColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// A small pill showing "+N more" when there are too many tags to display.
class CardTagOverflowPill extends StatelessWidget {
  const CardTagOverflowPill({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 24,
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
