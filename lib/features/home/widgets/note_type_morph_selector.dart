import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/nook_tokens.dart';
import '../../../core/widgets/animated_squircle.dart';
import '../../../data/tables/notes.dart';

/// Creative Material 3 Expressive note-type selector where each [NoteType]
/// morphs into its own signature squircle silhouette (`squircle`, `pill`,
/// or `clover`).
class NoteTypeMorphSelector extends StatelessWidget {
  const NoteTypeMorphSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final NoteType selected;
  final ValueChanged<NoteType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeTile(
            type: NoteType.text,
            title: 'Story',
            subtitle: 'Rich prose',
            icon: HugeIcons.strokeRoundedNote01,
            shape: SquircleShape.squircle,
            isSelected: selected == NoteType.text,
            onTap: () => onSelected(NoteType.text),
          ),
        ),
        const SizedBox(width: NookTokens.kSpacingSm),
        Expanded(
          child: _TypeTile(
            type: NoteType.checklist,
            title: 'Tasks',
            subtitle: 'Checklists',
            icon: HugeIcons.strokeRoundedCheckList,
            shape: SquircleShape.pill,
            isSelected: selected == NoteType.checklist,
            onTap: () => onSelected(NoteType.checklist),
          ),
        ),
        const SizedBox(width: NookTokens.kSpacingSm),
        Expanded(
          child: _TypeTile(
            type: NoteType.doodle,
            title: 'Sketch',
            subtitle: 'Freehand ink',
            icon: HugeIcons.strokeRoundedDrawingCompass,
            shape: SquircleShape.clover,
            isSelected: selected == NoteType.doodle,
            onTap: () => onSelected(NoteType.doodle),
          ),
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.shape,
    required this.isSelected,
    required this.onTap,
  });

  final NoteType type;
  final String title;
  final String subtitle;
  final List<List<dynamic>> icon;
  final SquircleShape shape;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.emphasizedDecelerate,
        padding: const EdgeInsets.symmetric(
          horizontal: NookTokens.kSpacingMd,
          vertical: NookTokens.kSpacingMd,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer.withValues(alpha: 0.45)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSquircle(
              shape: isSelected ? shape : SquircleShape.squircle,
              size: 48,
              color:
                  isSelected ? scheme.primary : scheme.surfaceContainerHighest,
              child: HugeIcon(
                icon: icon,
                size: 22,
                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: NookTokens.kSpacingSm),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: NookTokens.kFontFloor,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
