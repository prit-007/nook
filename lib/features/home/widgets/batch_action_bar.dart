import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

/// Floating batch action dock for multi-selected notes.
class BatchActionBar extends StatelessWidget {
  const BatchActionBar({
    super.key,
    required this.selectedCount,
    required this.allPinned,
    required this.onTogglePin,
    required this.onMoveToNotebook,
    required this.onAddTag,
    required this.onDelete,
    required this.onClose,
  });

  final int selectedCount;
  final bool allPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onMoveToNotebook;
  final VoidCallback onAddTag;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      selectedCount == 0
                          ? 'Select notes'
                          : '$selectedCount selected',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  if (selectedCount > 0) ...[
                    const SizedBox(width: 8),
                    _BatchIconButton(
                      icon: allPinned
                          ? HugeIcons.strokeRoundedPinOff
                          : HugeIcons.strokeRoundedPin,
                      tooltip: allPinned ? 'Unpin notes' : 'Pin notes',
                      onTap: onTogglePin,
                    ),
                    _BatchIconButton(
                      icon: HugeIcons.strokeRoundedBook02,
                      tooltip: 'Move to Notebook',
                      onTap: onMoveToNotebook,
                    ),
                    _BatchIconButton(
                      icon: HugeIcons.strokeRoundedTag01,
                      tooltip: 'Add Tag',
                      onTap: onAddTag,
                    ),
                    _BatchIconButton(
                      icon: HugeIcons.strokeRoundedDelete01,
                      tooltip: 'Move to Bin',
                      color: scheme.error,
                      onTap: onDelete,
                    ),
                  ],
                  const SizedBox(width: 4),
                  _BatchIconButton(
                    icon: HugeIcons.strokeRoundedCancel01,
                    tooltip: 'Cancel selection',
                    onTap: onClose,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BatchIconButton extends StatelessWidget {
  const _BatchIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final List<List<dynamic>> icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = color ?? scheme.onSurfaceVariant;

    return Semantics(
      label: tooltip,
      button: true,
      child: IconButton(
        icon: HugeIcon(
          icon: icon,
          color: iconColor,
          size: 20,
        ),
        tooltip: tooltip,
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
      ),
    );
  }
}
