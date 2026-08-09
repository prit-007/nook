import 'package:flutter/material.dart';

import '../../../data/tables/notes.dart';

/// Horizontal scrollable filter pill bar with glassmorphism styling.
class FilterPillBar extends StatelessWidget {
  const FilterPillBar({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  final NoteType? selectedType;
  final ValueChanged<NoteType?> onTypeSelected;

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
            isActive: selectedType == null,
            onTap: () => onTypeSelected(null),
          ),
          _FilterPill(
            label: 'Pinned',
            icon: Icons.push_pin_rounded,
            isActive: false,
            onTap: () {},
          ),
          _FilterPill(
            label: 'Text',
            isActive: selectedType == NoteType.text,
            onTap: () => onTypeSelected(NoteType.text),
          ),
          _FilterPill(
            label: 'Checklists',
            isActive: selectedType == NoteType.checklist,
            onTap: () => onTypeSelected(NoteType.checklist),
          ),
          _FilterPill(
            label: 'Doodles',
            isActive: selectedType == NoteType.doodle,
            onTap: () => onTypeSelected(NoteType.doodle),
          ),
          _FilterPill(
            label: 'Locked',
            icon: Icons.lock_rounded,
            isActive: false,
            onTap: () {},
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
    this.icon,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: isActive
                ? scheme.primary
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
