import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/nook_tokens.dart';
import 'animated_squircle.dart';

/// Floating Material 3 Expressive squircle status pill with optional Undo
/// or quick action button.
class NookStatusPill extends StatelessWidget {
  const NookStatusPill({
    super.key,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final List<List<dynamic>> icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NookTokens.kSpacingLg,
          vertical: NookTokens.kSpacingSm,
        ),
        decoration: ShapeDecoration(
          color: scheme.inverseSurface,
          shape: const SquircleBorder(cornerRadius: NookTokens.kRadiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: icon,
              size: 18,
              color: scheme.onInverseSurface,
            ),
            const SizedBox(width: NookTokens.kSpacingSm),
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onInverseSurface,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: NookTokens.kSpacingMd),
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.inversePrimary,
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
