import 'package:flutter/material.dart';

import '../../../data/database.dart';
import '../../../data/tables/notes.dart';

/// Full-width immersive banner card for pinned/featured notes.
/// Magazine-style hero card with tonal background from note.colorSeed.
class NoteBannerCard extends StatelessWidget {
  const NoteBannerCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  Color _bannerColor(BuildContext context) {
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
      child: Container(
        height: 220,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: _bannerColor(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _typeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        if (note.locked) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: scheme.onPrimaryContainer
                                .withValues(alpha: 0.6),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note.plainText != null &&
                        note.plainText!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note.plainText!,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              scheme.onPrimaryContainer.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (note.pinned)
              Positioned(
                top: 16,
                right: 16,
                child: Icon(
                  Icons.push_pin_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get _typeLabel => switch (note.type) {
        NoteType.checklist => 'Checklist',
        NoteType.doodle => 'Doodle',
        NoteType.mixed => 'Mixed',
        NoteType.text => 'Note',
      };
}
