import 'package:flutter/material.dart';

import '../../../data/database.dart';

/// Split-view card for doodle notes.
/// Left side: text info. Right side: visual/icon area.
class NoteDoodleCard extends StatelessWidget {
  const NoteDoodleCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  Color _visualColor(BuildContext context) {
    if (note.colorSeed != null) {
      final seed = Color(
        int.parse('FF${note.colorSeed!.replaceFirst('#', '')}', radix: 16),
      );
      return ColorScheme.fromSeed(seedColor: seed).primaryContainer;
    }
    return Theme.of(context).colorScheme.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'note-${note.id}',
        child: Container(
          height: 140,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.draw_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Canvas Doodle',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        note.title.isEmpty ? 'Untitled doodle' : note.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (note.pinned) ...[
                        const SizedBox(height: 4),
                        Icon(
                          Icons.push_pin_rounded,
                          size: 12,
                          color: scheme.outline,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: _visualColor(context),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(24),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.gesture_rounded,
                      size: 36,
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
