import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/nook_tokens.dart';
import 'animated_squircle.dart';

/// Quick-start action displayed inside [SmartEmptyPrompt].
class SmartStarterAction {
  const SmartStarterAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final List<List<dynamic>> icon;
  final VoidCallback onTap;
}

/// Attentive empty state featuring an animated squircle emblem and one-tap
/// contextual starter actions.
class SmartEmptyPrompt extends StatelessWidget {
  const SmartEmptyPrompt({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final List<SmartStarterAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(NookTokens.kSpacingXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSquircle(
            shape: SquircleShape.clover,
            size: 72,
            color: scheme.primaryContainer,
            child: HugeIcon(
              icon: icon,
              size: 32,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: NookTokens.kSpacingLg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: NookTokens.kSpacingXs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: NookTokens.kSpacingLg),
            Wrap(
              spacing: NookTokens.kSpacingSm,
              runSpacing: NookTokens.kSpacingSm,
              alignment: WrapAlignment.center,
              children: [
                for (final action in actions)
                  ActionChip(
                    avatar: HugeIcon(
                      icon: action.icon,
                      size: 16,
                      color: scheme.primary,
                    ),
                    label: Text(action.label),
                    onPressed: action.onTap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
