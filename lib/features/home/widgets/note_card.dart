import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nook/core/theme/design_tokens.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';

import 'note_quick_actions_sheet.dart';

class NoteCard extends StatefulWidget {
  const NoteCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _isPressed = false;

  ColorScheme _cardScheme(BuildContext context) {
    if (widget.note.colorSeed != null && widget.note.colorSeed!.isNotEmpty) {
      final seed = NookColors.parseHex(widget.note.colorSeed);
      return ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Theme.of(context).brightness,
      );
    }
    return Theme.of(context).colorScheme;
  }

  @override
  Widget build(BuildContext context) {
    final cardScheme = _cardScheme(context);

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
              decoration: BoxDecoration(
                color: cardScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: cardScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _typeIcon(cardScheme),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                widget.note.title.isNotEmpty
                                    ? widget.note.title
                                    : 'Untitled',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: widget.note.locked
                                      ? cardScheme.onSurface
                                          .withValues(alpha: 0.3)
                                      : cardScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: widget.note.locked
                              ? _lockedPreview(cardScheme)
                              : _contentPreview(cardScheme),
                        ),
                      ],
                    ),
                  ),
                  if (widget.note.pinned)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cardScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.push_pin,
                          size: 14,
                          color: cardScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  if (widget.note.locked)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cardScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.lock,
                          size: 14,
                          color: cardScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeIcon(ColorScheme scheme) {
    final icon = switch (widget.note.type) {
      NoteType.checklist => Icons.checklist,
      NoteType.doodle => Icons.draw,
      NoteType.text || NoteType.mixed => Icons.notes,
    };
    return Icon(icon, size: 16, color: scheme.primary);
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
    final text = widget.note.plainText ?? widget.note.title;
    if (text.isEmpty) {
      return Center(
        child: Icon(
          widget.note.type == NoteType.doodle ? Icons.draw : Icons.notes,
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
