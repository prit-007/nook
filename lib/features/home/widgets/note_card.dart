import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/theme/note_theme.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';

import 'card_tag_pill.dart';
import 'note_quick_actions_sheet.dart';

class NoteCard extends ConsumerStatefulWidget {
  const NoteCard({super.key, required this.note, this.onTap, this.heroTag});

  final Note note;
  final VoidCallback? onTap;

  /// Hero tag used for route transitions. Defaults to `note-<id>`.
  ///
  /// Pass a scoped value (e.g. `nb-<notebookId>-note-<id>`) when the same note
  /// may appear in multiple master-detail panes at once, so no two [Hero]s
  /// share a tag within the same subtree.
  final String? heroTag;

  @override
  ConsumerState<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends ConsumerState<NoteCard> {
  bool _isPressed = false;
  List<ChecklistItem> _checklistItems = [];
  bool _loadingChecklist = false;
  List<Tag> _tags = [];
  String? _notebookName;

  bool get _hasColor =>
      widget.note.colorSeed != null && widget.note.colorSeed!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.note.type == NoteType.checklist) {
      _loadChecklistItems();
    }
    _loadMetadata();
  }

  @override
  void didUpdateWidget(covariant NoteCard oldWidget) {
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
          tag: widget.heroTag ?? 'note-${widget.note.id}',
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: cardScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (_hasColor)
                    Positioned.fill(
                      child: ColoredBox(
                        color:
                            cardScheme.primaryContainer.withValues(alpha: 0.08),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: Row(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: widget.note.locked
                              ? _lockedPreview(cardScheme)
                              : _contentPreview(cardScheme),
                        ),
                        if (_tags.isNotEmpty || _notebookName != null) ...[
                          const SizedBox(height: 8),
                          _metadataRow(cardScheme),
                        ],
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
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedPin,
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
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedLock,
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
      NoteType.checklist => HugeIcons.strokeRoundedCheckList,
      NoteType.doodle => HugeIcons.strokeRoundedDrawingMode,
      NoteType.mixed => HugeIcons.strokeRoundedLayers01,
      NoteType.text => HugeIcons.strokeRoundedNotebook01,
    };
    return HugeIcon(icon: icon, size: 16, color: scheme.primary);
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
    if (widget.note.type == NoteType.checklist) {
      return _checklistPreview(scheme);
    }

    final text = widget.note.plainText ?? widget.note.title;
    if (text.isEmpty) {
      return Center(
        child: HugeIcon(
          icon: widget.note.type == NoteType.doodle
              ? HugeIcons.strokeRoundedDrawingMode
              : HugeIcons.strokeRoundedNotebook01,
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
      return Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
          size: 32,
          color: scheme.onSurface.withValues(alpha: 0.15),
        ),
      );
    }

    final checkedCount = _checklistItems.where((i) => i.checked).length;
    final totalCount = _checklistItems.length;
    final displayItems = _checklistItems.take(4).toList();

    // The card grid gives a bounded height; wrap the item list in a
    // non-interactive scroll view so a long checklist ellipsizes instead of
    // overflowing the card's bottom edge (RenderFlex overflow).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress indicator
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
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // First few items, clipped to the card's bounded preview area so a
        // long checklist never overflows the bottom edge.
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            clipBehavior: Clip.hardEdge,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in displayItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: item.checked
                              ? HugeIcons.strokeRoundedCheckmarkCircle01
                              : HugeIcons.strokeRoundedCircle,
                          size: 12,
                          color: item.checked
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.itemText,
                            style: TextStyle(
                              fontSize: 11,
                              color: item.checked
                                  ? scheme.onSurface.withValues(alpha: 0.35)
                                  : scheme.onSurface.withValues(alpha: 0.7),
                              decoration: item.checked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (totalCount > 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${totalCount - 4} more',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
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
