import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/note_theme.dart';
import '../../../data/database.dart';
import '../../../data/repositories/checklist_item_repository.dart';
import '../../../data/tables/notes.dart';
import 'note_quick_actions_sheet.dart';

class NoteBannerCard extends ConsumerStatefulWidget {
  const NoteBannerCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  ConsumerState<NoteBannerCard> createState() => _NoteBannerCardState();
}

class _NoteBannerCardState extends ConsumerState<NoteBannerCard> {
  bool _isPressed = false;
  List<ChecklistItem> _items = [];

  @override
  void initState() {
    super.initState();
    if (widget.note.type == NoteType.checklist) _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    final items = await ChecklistItemRepository(ref.read(databaseProvider))
        .getItems(widget.note.id);
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    final bannerScheme = noteSchemeFor(context, widget.note.colorSeed);

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
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Hero(
          tag: 'note-${widget.note.id}',
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: 220,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: bannerScheme.primaryContainer,
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
                                  color: bannerScheme.onPrimaryContainer
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _typeLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: bannerScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              if (widget.note.locked) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.lock_rounded,
                                  size: 14,
                                  color: bannerScheme.onPrimaryContainer
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
                              color: bannerScheme.onPrimaryContainer,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.note.type == NoteType.checklist &&
                              _items.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _items
                                  .take(3)
                                  .map((item) =>
                                      '${item.checked ? '✓' : '○'} ${item.itemText}')
                                  .join('\n'),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: bannerScheme.onPrimaryContainer
                                    .withValues(alpha: 0.75),
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else if (widget.note.plainText != null &&
                              widget.note.plainText!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.note.plainText!,
                              style: TextStyle(
                                fontSize: 14,
                                color: bannerScheme.onPrimaryContainer
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
                        color: bannerScheme.onPrimaryContainer
                            .withValues(alpha: 0.6),
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

  String get _typeLabel => switch (widget.note.type) {
        NoteType.checklist => 'Checklist',
        NoteType.doodle => 'Doodle',
        NoteType.mixed => 'Mixed',
        NoteType.text => 'Note',
      };
}
