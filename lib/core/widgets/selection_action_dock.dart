import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../theme/app_motion.dart';
import '../theme/nook_tokens.dart';

/// Morphs smoothly between [normalDock] and a contextual batch-action bar
/// when notes are multi-selected.
class SelectionActionDock extends StatelessWidget {
  const SelectionActionDock({
    super.key,
    required this.isSelecting,
    required this.selectedCount,
    required this.normalDock,
    required this.onClearSelection,
    this.onPinSelected,
    this.onArchiveSelected,
    this.onDeleteSelected,
  });

  final bool isSelecting;
  final int selectedCount;
  final Widget normalDock;
  final VoidCallback onClearSelection;
  final VoidCallback? onPinSelected;
  final VoidCallback? onArchiveSelected;
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return AnimatedSwitcher(
      duration: AppMotion.standard,
      switchInCurve: AppMotion.emphasizedDecelerate,
      switchOutCurve: AppMotion.emphasizedAccelerate,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
      child: isSelecting
          ? Container(
              key: const ValueKey('selection-action-bar'),
              height: 64,
              padding: const EdgeInsets.symmetric(
                horizontal: NookTokens.kSpacingLg,
              ),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: tokens.borderRadiusPill,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Clear selection',
                    onPressed: onClearSelection,
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 20,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '$selectedCount selected',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: NookTokens.kSpacingMd),
                  if (onPinSelected != null)
                    IconButton(
                      tooltip: 'Pin selected',
                      onPressed: onPinSelected,
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedPin,
                        size: 20,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  if (onArchiveSelected != null)
                    IconButton(
                      tooltip: 'Archive selected',
                      onPressed: onArchiveSelected,
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedArchive,
                        size: 20,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  if (onDeleteSelected != null)
                    IconButton(
                      tooltip: 'Delete selected',
                      onPressed: onDeleteSelected,
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedDelete01,
                        size: 20,
                        color: scheme.error,
                      ),
                    ),
                ],
              ),
            )
          : KeyedSubtree(
              key: const ValueKey('normal-dock-wrapper'),
              child: normalDock,
            ),
    );
  }
}
