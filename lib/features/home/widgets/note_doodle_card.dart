import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/note_theme.dart';
import '../../../data/database.dart';
import 'note_quick_actions_sheet.dart';

/// Split-view card for doodle notes with theme awareness and gesture feedback.
class NoteDoodleCard extends StatefulWidget {
  const NoteDoodleCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  State<NoteDoodleCard> createState() => _NoteDoodleCardState();
}

class _NoteDoodleCardState extends State<NoteDoodleCard> {
  bool _isPressed = false;

  bool get _hasColor =>
      widget.note.colorSeed != null && widget.note.colorSeed!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cardScheme = noteSchemeFor(context, widget.note.colorSeed);

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
              height: 140,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _hasColor
                    ? Color.alphaBlend(
                        cardScheme.primaryContainer.withValues(alpha: 0.08),
                        cardScheme.surfaceContainerLow,
                      )
                    : cardScheme.surfaceContainerLow,
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
                                size: 15,
                                color: cardScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Doodle',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: cardScheme.primary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.note.title.isEmpty
                                ? 'Untitled doodle'
                                : widget.note.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cardScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.note.pinned) ...[
                            const SizedBox(height: 6),
                            Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: cardScheme.primary,
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
                        color: cardScheme.primaryContainer,
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(24),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.gesture_rounded,
                          size: 40,
                          color: cardScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
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
}
