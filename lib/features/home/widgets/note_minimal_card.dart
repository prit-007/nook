import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/note_theme.dart';
import '../../../data/database.dart';
import '../../../data/repositories/checklist_item_repository.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../data/tables/notes.dart';
import 'card_tag_pill.dart';
import 'note_quick_actions_sheet.dart';

class NoteMinimalCard extends ConsumerStatefulWidget {
  const NoteMinimalCard({super.key, required this.note, this.onTap});

  final Note note;
  final VoidCallback? onTap;

  @override
  ConsumerState<NoteMinimalCard> createState() => _NoteMinimalCardState();
}

class _NoteMinimalCardState extends ConsumerState<NoteMinimalCard> {
  bool _isPressed = false;
  List<ChecklistItem> _checklistItems = [];
  bool _loadingChecklist = false;
  List<Tag> _tags = [];
  String? _notebookName;

  @override
  void initState() {
    super.initState();
    if (widget.note.type == NoteType.checklist) {
      _loadChecklistItems();
    }
    _loadMetadata();
  }

  @override
  void didUpdateWidget(covariant NoteMinimalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      if (widget.note.type == NoteType.checklist) {
        _loadChecklistItems();
      }
      _loadMetadata();
    }
  }

  Future<void> _loadChecklistItems() async {
    _loadingChecklist = true;
    final db = ref.read(databaseProvider);
    final items = await ChecklistItemRepository(db).getItems(widget.note.id);
    if (mounted) {
      setState(() {
        _checklistItems = items;
        _loadingChecklist = false;
      });
    }
  }

  Future<void> _loadMetadata() async {
    final db = ref.read(databaseProvider);
    final tags = await TagRepository(db).getTagsForNote(widget.note.id);
    String? nbName;
    if (widget.note.notebookId != null) {
      final nb =
          await NotebookRepository(db).getNotebookById(widget.note.notebookId!);
      nbName = nb?.name;
    }
    if (mounted) {
      setState(() {
        _tags = tags;
        _notebookName = nbName;
      });
    }
  }

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
                              HugeIcon(
                                  icon: _typeIcon,
                                  size: 15,
                                  color: cardScheme.primary),
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
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedPin,
                              size: 16,
                              color: cardScheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.note.locked)
                        _lockedPreview(cardScheme)
                      else ...[
                        Text(
                          widget.note.title.isEmpty
                              ? 'Untitled'
                              : widget.note.title,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: cardScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.note.type == NoteType.checklist) ...[
                          const SizedBox(height: 8),
                          _checklistPreview(cardScheme),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.note.plainText ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                              color:
                                  cardScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                      if (_tags.isNotEmpty || _notebookName != null) ...[
                        const SizedBox(height: 10),
                        _metadataRow(cardScheme),
                      ],
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

  List<List<dynamic>> get _typeIcon => switch (widget.note.type) {
        NoteType.checklist => HugeIcons.strokeRoundedCheckList,
        NoteType.doodle => HugeIcons.strokeRoundedDrawingMode,
        NoteType.mixed => HugeIcons.strokeRoundedLayers01,
        NoteType.text => HugeIcons.strokeRoundedNotebook01,
      };

  String get _typeLabel => switch (widget.note.type) {
        NoteType.checklist => 'Checklist',
        NoteType.doodle => 'Doodle',
        NoteType.mixed => 'Mixed',
        NoteType.text => 'Quick Thought',
      };

  Widget _checklistPreview(ColorScheme scheme) {
    if (_loadingChecklist) {
      return Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    if (_checklistItems.isEmpty) {
      return Text(
        'No tasks yet',
        style: TextStyle(
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    final checkedCount = _checklistItems.where((i) => i.checked).length;
    final totalCount = _checklistItems.length;
    final displayItems = _checklistItems.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalCount > 0 ? checkedCount / totalCount : 0,
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$checkedCount/$totalCount',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Items
        for (final item in displayItems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                  size: 14,
                  color: item.checked
                      ? scheme.primary
                      : scheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.itemText,
                    style: TextStyle(
                      fontSize: 14,
                      color: item.checked
                          ? scheme.onSurface.withValues(alpha: 0.35)
                          : scheme.onSurface,
                      decoration:
                          item.checked ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        if (totalCount > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+${totalCount - 5} more',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
      ],
    );
  }

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
              HugeIcon(
                  icon: HugeIcons.strokeRoundedLock,
                  size: 16,
                  color: scheme.primary),
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

  Widget _metadataRow(ColorScheme scheme) {
    return Row(
      children: [
        if (_notebookName != null) ...[
          HugeIcon(
            icon: HugeIcons.strokeRoundedFolder01,
            size: 10,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              _notebookName!,
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        if (_tags.isNotEmpty) ...[
          if (_notebookName != null) const SizedBox(width: 6),
          Flexible(
            child: Wrap(
              spacing: 3,
              runSpacing: 2,
              children: [
                ..._tags.take(2).map((tag) => CardTagPill(
                      label: tag.name,
                      colorSeed: tag.colorSeed,
                    )),
                if (_tags.length > 2)
                  CardTagOverflowPill(count: _tags.length - 2),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
