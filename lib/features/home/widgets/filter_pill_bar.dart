import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/nook_tokens.dart';
import '../../../data/tables/notes.dart';

class FilterPillBar extends StatelessWidget {
  const FilterPillBar({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    this.counts,
    this.favoritesOnly = false,
    this.onFavoritesToggled,
    this.favoritesCount,
  });

  final NoteType? selectedType;
  final ValueChanged<NoteType?> onTypeSelected;
  final Map<NoteType?, int>? counts;
  final bool favoritesOnly;
  final ValueChanged<bool>? onFavoritesToggled;
  final int? favoritesCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterPill(
            label: 'All notes',
            count: counts?[null],
            isActive: !favoritesOnly && selectedType == null,
            onTap: () {
              if (favoritesOnly) onFavoritesToggled?.call(false);
              onTypeSelected(null);
            },
          ),
          _FilterPill(
            label: 'Favorites',
            icon: HugeIcons.strokeRoundedPin,
            count: favoritesCount,
            isActive: favoritesOnly,
            onTap: () => onFavoritesToggled?.call(!favoritesOnly),
          ),
          _FilterPill(
            label: 'Text',
            count: counts?[NoteType.text],
            isActive: !favoritesOnly && selectedType == NoteType.text,
            onTap: () {
              if (favoritesOnly) onFavoritesToggled?.call(false);
              onTypeSelected(NoteType.text);
            },
          ),
          _FilterPill(
            label: 'Checklists',
            count: counts?[NoteType.checklist],
            isActive: !favoritesOnly && selectedType == NoteType.checklist,
            onTap: () {
              if (favoritesOnly) onFavoritesToggled?.call(false);
              onTypeSelected(NoteType.checklist);
            },
          ),
          _FilterPill(
            label: 'Doodles',
            count: counts?[NoteType.doodle],
            isActive: !favoritesOnly && selectedType == NoteType.doodle,
            onTap: () {
              if (favoritesOnly) onFavoritesToggled?.call(false);
              onTypeSelected(NoteType.doodle);
            },
          ),
          _FilterPill(
            label: 'Mixed',
            count: counts?[NoteType.mixed],
            isActive: !favoritesOnly && selectedType == NoteType.mixed,
            onTap: () {
              if (favoritesOnly) onFavoritesToggled?.call(false);
              onTypeSelected(NoteType.mixed);
            },
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.count,
    this.icon,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? count;
  final List<List<dynamic>>? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        label: '$label${count != null && count! > 0 ? ', $count items' : ''}',
        button: true,
        selected: isActive,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.short4,
            curve: AppMotion.emphasizedDecelerate,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: isActive
                  ? scheme.primary
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: context.tokens.borderRadiusPill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  HugeIcon(
                    icon: icon!,
                    size: 14,
                    color:
                        isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color:
                        isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? scheme.onPrimary.withValues(alpha: 0.2)
                          : scheme.surfaceContainerHigh,
                      borderRadius: context.tokens.borderRadiusXs,
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
