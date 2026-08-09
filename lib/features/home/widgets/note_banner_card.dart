import 'package:flutter/material.dart';

import '../../../data/database.dart';
import '../../../data/tables/notes.dart';

class NoteBannerCard extends StatefulWidget {
  const NoteBannerCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  State<NoteBannerCard> createState() => _NoteBannerCardState();
}

class _NoteBannerCardState extends State<NoteBannerCard> {
  bool _isPressed = false;

  Color _bannerColor(BuildContext context) {
    if (widget.note.colorSeed != null) {
      final seed = Color(
        int.parse(
          'FF${widget.note.colorSeed!.replaceFirst('#', '')}',
          radix: 16,
        ),
      );
      return ColorScheme.fromSeed(seedColor: seed).primaryContainer;
    }
    return Theme.of(context).colorScheme.primaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bannerBg = _bannerColor(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Hero(
          tag: 'note-${widget.note.id}',
          child: Container(
            height: 220,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: bannerBg,
              boxShadow: [
                BoxShadow(
                  color: bannerBg.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
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
                            if (widget.note.locked) ...[
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
                          widget.note.title.isEmpty
                              ? 'Untitled'
                              : widget.note.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: scheme.onPrimaryContainer,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.note.plainText != null &&
                            widget.note.plainText!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.note.plainText!,
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onPrimaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (widget.note.pinned)
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
        ),
      ),
    );
  }

  String get _typeLabel => switch (widget.note.type) {
        NoteType.checklist => 'Checklist',
        NoteType.doodle => 'Doodle',
        NoteType.mixed => 'Mixed',
        NoteType.text => 'Note',
      };
}
