import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../data/database.dart';
import '../../../data/tables/notes.dart';

/// Clean typographic card for text/checklist notes.
/// Whitespace-heavy, typography-forward design.
class NoteMinimalCard extends StatelessWidget {
  const NoteMinimalCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: note.colorSeed != null
              ? _cardColor(context)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: note.colorSeed == null
              ? Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _typeIcon,
                      size: 14,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _typeLabel,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (note.pinned)
                  Icon(
                    Icons.push_pin_rounded,
                    size: 16,
                    color: scheme.outline,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (note.locked)
              _lockedPreview(scheme)
            else
              Text(
                note.title.isEmpty
                    ? (note.plainText ?? 'Untitled')
                    : (note.plainText ?? note.title),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: scheme.onSurface,
                ),
              ),
            if (note.locked) ...[
              const SizedBox(height: 8),
              Icon(
                Icons.lock_rounded,
                size: 14,
                color: scheme.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _cardColor(BuildContext context) {
    final seed = Color(
      int.parse('FF${note.colorSeed!.replaceFirst('#', '')}', radix: 16),
    );
    return ColorScheme.fromSeed(seedColor: seed).surfaceContainerLow;
  }

  IconData get _typeIcon => switch (note.type) {
        NoteType.checklist => Icons.checklist_rounded,
        NoteType.doodle => Icons.draw_rounded,
        NoteType.mixed => Icons.layers_rounded,
        NoteType.text => Icons.notes_rounded,
      };

  String get _typeLabel => switch (note.type) {
        NoteType.checklist => 'Checklist',
        NoteType.doodle => 'Doodle',
        NoteType.mixed => 'Mixed',
        NoteType.text => 'Quick Thought',
      };

  Widget _lockedPreview(ColorScheme scheme) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
