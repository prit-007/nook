import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/note_theme.dart';
import '../../../data/database.dart';
import '../../../data/repositories/attachment_repository.dart';
import '../../../data/tables/attachments.dart';
import 'note_quick_actions_sheet.dart';

/// Split-view card for doodle notes with theme awareness and gesture feedback.
class NoteDoodleCard extends ConsumerStatefulWidget {
  const NoteDoodleCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  ConsumerState<NoteDoodleCard> createState() => _NoteDoodleCardState();
}

class _NoteDoodleCardState extends ConsumerState<NoteDoodleCard> {
  bool _isPressed = false;
  String? _thumbnailPath;

  bool get _hasColor =>
      widget.note.colorSeed != null && widget.note.colorSeed!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant NoteDoodleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final db = ref.read(databaseProvider);
    final attachments =
        await AttachmentRepository(db).getAllForNote(widget.note.id);
    if (!mounted) return;
    final doodleAttachment = attachments
        .where((a) => a.type == AttachmentType.doodleLayer)
        .firstOrNull;
    if (mounted) {
      setState(() {
        _thumbnailPath = doodleAttachment?.thumbnailPath;
      });
    }
  }

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
                    child: _buildThumbnail(cardScheme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme cardScheme) {
    if (_thumbnailPath != null && File(_thumbnailPath!).existsSync()) {
      return ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(24),
        ),
        child: Image.file(
          File(_thumbnailPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackIcon(cardScheme),
        ),
      );
    }
    return _fallbackIcon(cardScheme);
  }

  Widget _fallbackIcon(ColorScheme cardScheme) {
    return Container(
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
          color: cardScheme.onPrimaryContainer.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
