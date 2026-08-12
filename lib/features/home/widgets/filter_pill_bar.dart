import 'package:flutter/material.dart';

import '../../../data/tables/notes.dart';

class FilterPillBar extends StatelessWidget {
  const FilterPillBar({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    this.counts,
  });

  final NoteType? selectedType;
  final ValueChanged<NoteType?> onTypeSelected;
  final Map<NoteType?, int>? counts;

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
            isActive: selectedType == null,
            onTap: () => onTypeSelected(null),
          ),
          _FilterPill(
            label: 'Text',
            count: counts?[NoteType.text],
            isActive: selectedType == NoteType.text,
            onTap: () => onTypeSelected(NoteType.text),
          ),
          _FilterPill(
            label: 'Checklists',
            count: counts?[NoteType.checklist],
            isActive: selectedType == NoteType.checklist,
            onTap: () => onTypeSelected(NoteType.checklist),
          ),
          _FilterPill(
            label: 'Doodles',
            count: counts?[NoteType.doodle],
            isActive: selectedType == NoteType.doodle,
            onTap: () => onTypeSelected(NoteType.doodle),
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
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int? count;

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
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color:
                          isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
