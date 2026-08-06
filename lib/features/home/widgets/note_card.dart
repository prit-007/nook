import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';

/// Displays a single note as a card in the home grid.
/// From stitch prompt #3: "Each card has rounded 20px corners, soft tonal
/// background color unique per card, subtle drop shadow."
class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note});

  final Note note;

  Color _cardColor(BuildContext context) {
    if (note.colorSeed != null) {
      final seed = Color(
        int.parse('FF${note.colorSeed!.replaceFirst('#', '')}', radix: 16),
      );
      return ColorScheme.fromSeed(seedColor: seed).surfaceContainerLow;
    }
    return Theme.of(context).colorScheme.surfaceContainerLow;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Content area
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note type icon + title
                Row(
                  children: [
                    _typeIcon(scheme),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: note.locked
                              ? scheme.onSurface.withValues(alpha: 0.3)
                              : scheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Preview area
                Expanded(
                  child: note.locked
                      ? _lockedPreview(scheme)
                      : _contentPreview(scheme),
                ),
              ],
            ),
          ),
          // Pin badge (top-right)
          if (note.pinned)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.push_pin,
                  size: 14,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          // Lock badge (bottom-right)
          if (note.locked)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.lock,
                  size: 14,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _typeIcon(ColorScheme scheme) {
    final icon = switch (note.type) {
      NoteType.checklist => Icons.checklist,
      NoteType.doodle => Icons.draw,
      NoteType.text || NoteType.mixed => Icons.notes,
    };
    return Icon(icon, size: 16, color: scheme.onSurface.withValues(alpha: 0.5));
  }

  Widget _lockedPreview(ColorScheme scheme) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _contentPreview(ColorScheme scheme) {
    final text = note.plainText ?? note.title;
    if (text.isEmpty) {
      return Center(
        child: Icon(
          note.type == NoteType.doodle ? Icons.draw : Icons.notes,
          size: 32,
          color: scheme.onSurface.withValues(alpha: 0.15),
        ),
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: scheme.onSurface.withValues(alpha: 0.6),
        height: 1.4,
      ),
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
    );
  }
}
