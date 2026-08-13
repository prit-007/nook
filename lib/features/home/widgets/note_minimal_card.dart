import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/note_theme.dart';
import '../../../data/database.dart';
import '../../../data/tables/notes.dart';
import 'note_quick_actions_sheet.dart';

class NoteMinimalCard extends StatefulWidget {
  const NoteMinimalCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  State<NoteMinimalCard> createState() => _NoteMinimalCardState();
}

class _NoteMinimalCardState extends State<NoteMinimalCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final cardScheme = noteSchemeFor(context, widget.note.colorSeed);
    final hasColorSeed =
        widget.note.colorSeed != null && widget.note.colorSeed!.isNotEmpty;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        NoteQuickActionsSheet.show(context, widget.note);
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Hero(
          tag: 'note-${widget.note.id}',
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cardScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(26),
                border: hasColorSeed
                    ? Border.all(
                        color: cardScheme.primary.withValues(alpha: 0.12),
                        width: 1,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: cardScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (hasColorSeed)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: cardScheme.primaryContainer
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(_typeIcon,
                                  size: 15, color: cardScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                _typeLabel,
                                style: TextStyle(
                                  color: cardScheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          if (widget.note.pinned)
                            Icon(
                              Icons.push_pin_rounded,
                              size: 16,
                              color: cardScheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.note.locked)
                        _lockedPreview(cardScheme)
                      else
                        Text(
                          widget.note.title.isEmpty
                              ? (widget.note.plainText ?? 'Untitled')
                              : (widget.note.plainText ?? widget.note.title),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: cardScheme.onSurface,
                          ),
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData get _typeIcon => switch (widget.note.type) {
        NoteType.checklist => Icons.checklist_rounded,
        NoteType.doodle => Icons.draw_rounded,
        NoteType.mixed => Icons.layers_rounded,
        NoteType.text => Icons.notes_rounded,
      };

  String get _typeLabel => switch (widget.note.type) {
        NoteType.checklist => 'Checklist',
        NoteType.doodle => 'Doodle',
        NoteType.mixed => 'Mixed',
        NoteType.text => 'Quick Thought',
      };

  Widget _lockedPreview(ColorScheme scheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 44,
          color: scheme.surface.withValues(alpha: 0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Biometrics required',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
