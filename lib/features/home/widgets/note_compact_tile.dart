import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/nook_tokens.dart';
import '../../../data/database.dart';
import '../../../data/tables/notes.dart';

/// High-density scannable row for [HomeViewMode.compact].
class NoteCompactTile extends StatelessWidget {
  const NoteCompactTile({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 59)}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  List<List<dynamic>> get _typeIcon {
    switch (note.type) {
      case NoteType.checklist:
        return HugeIcons.strokeRoundedCheckmarkSquare02;
      case NoteType.doodle:
        return HugeIcons.strokeRoundedPen01;
      case NoteType.text:
      case NoteType.mixed:
        return HugeIcons.strokeRoundedNote01;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        note.title.trim().isEmpty ? 'Untitled note' : note.title.trim();

    return Material(
      color: isSelected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerLow,
      borderRadius: context.tokens.borderRadiusMd,
      child: InkWell(
        borderRadius: context.tokens.borderRadiusMd,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (isSelectionMode) ...[
                HugeIcon(
                  icon: isSelected
                      ? HugeIcons.strokeRoundedCheckmarkSquare02
                      : HugeIcons.strokeRoundedSquare,
                  size: 20,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
              ] else ...[
                HugeIcon(
                  icon: note.locked ? HugeIcons.strokeRoundedLock : _typeIcon,
                  size: 18,
                  color: note.pinned
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(note.updatedAt),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (note.pinned) ...[
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedPin,
                  size: 16,
                  color: scheme.primary,
                ),
              ],
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
