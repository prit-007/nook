import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/masked_reveal.dart';
import '../../core/widgets/masked_reveal_text.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/parallax_card.dart';
import '../../data/database.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/tables/notes.dart';
import '../home/widgets/note_card.dart';

/// Tag detail — notes filtered by tag with a macro-typography SliverAppBar.
class TagDetailScreen extends ConsumerStatefulWidget {
  const TagDetailScreen({super.key, required this.tagId});

  final String tagId;

  @override
  ConsumerState<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends ConsumerState<TagDetailScreen> {
  String _tagName = '';
  Color? _tagColor;
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final tagRepo = TagRepository(db);

    final tag = await tagRepo.getTagById(widget.tagId);
    if (tag != null) {
      _tagName = tag.name;
      _tagColor = NookColors.parseHex(tag.colorSeed);
    }

    final results = await tagRepo.getNotesForTag(widget.tagId);

    if (!mounted) return;
    setState(() {
      _notes = results;
      _loading = false;
    });
  }

  void _showAddNotesSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddNotesToTagSheet(
        tagId: widget.tagId,
        onNotesAdded: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-tag-detail',
        onPressed: _showAddNotesSheet,
        tooltip: 'Add notes',
        backgroundColor: _tagColor ?? scheme.primary,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          size: 24,
          color: scheme.onPrimary,
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: _tagColor ?? scheme.primary,
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar.large(
                  expandedHeight: 150.0,
                  backgroundColor: scheme.surface,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      color: scheme.onSurface,
                      size: 24,
                    ),
                    tooltip: 'Go back',
                    onPressed: () => context.pop(),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_tagColor != null)
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedTag01,
                            color: _tagColor,
                            size: 22,
                          ),
                        if (_tagColor != null) const SizedBox(width: 8),
                        MaskedRevealText(
                          _tagName.isEmpty ? 'Tag' : _tagName,
                          style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            fontSize: 28, // Macro typography
                            color: _tagColor ?? scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_notes.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: HugeIcons.strokeRoundedFile01,
                      title: 'No notes found',
                      subtitle: 'Tag your notes to see them here',
                      animate: false,
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      DockSafeArea.bottomOf(context) + 16,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.78, // Matching elegant layout
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final card = NoteCard(
                            key: ValueKey(_notes[index].id),
                            note: _notes[index],
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.push('/note/${_notes[index].id}');
                            },
                          );
                          if (reduceMotion) return card;
                          return ParallaxCard(
                            child: MaskedReveal(
                              delay: Duration(
                                milliseconds: (index * 60).clamp(0, 450),
                              ),
                              child: card,
                            ),
                          );
                        },
                        childCount: _notes.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
    );
  }
}

class _AddNotesToTagSheet extends ConsumerStatefulWidget {
  const _AddNotesToTagSheet({
    required this.tagId,
    this.onNotesAdded,
  });

  final String tagId;
  final VoidCallback? onNotesAdded;

  @override
  ConsumerState<_AddNotesToTagSheet> createState() =>
      _AddNotesToTagSheetState();
}

class _AddNotesToTagSheetState extends ConsumerState<_AddNotesToTagSheet> {
  List<Note> _untaggedNotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final tagRepo = TagRepository(db);

    final results = await (db.select(db.notes)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();

    final taggedIds = <String>{};
    for (final note in results) {
      final tags = await tagRepo.getTagsForNote(note.id);
      if (tags.any((t) => t.id == widget.tagId)) {
        taggedIds.add(note.id);
      }
    }

    if (mounted) {
      setState(() {
        _untaggedNotes =
            results.where((n) => !taggedIds.contains(n.id)).toList();
        _loading = false;
      });
    }
  }

  Future<void> _tagNote(String noteId) async {
    final db = ref.read(databaseProvider);
    final repo = TagRepository(db);
    await repo.assignTagToNote(noteId, widget.tagId);
    widget.onNotesAdded?.call();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add notes to tag',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Select notes to tag them here.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _untaggedNotes.isEmpty
                        ? Center(
                            child: Text(
                              'All notes are already tagged',
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _untaggedNotes.length,
                            itemBuilder: (context, index) {
                              final note = _untaggedNotes[index];
                              return ListTile(
                                leading: HugeIcon(
                                  icon: note.type == NoteType.checklist
                                      ? HugeIcons.strokeRoundedCheckList
                                      : note.type == NoteType.doodle
                                          ? HugeIcons.strokeRoundedDrawingMode
                                          : HugeIcons.strokeRoundedNotebook01,
                                  size: 20,
                                  color: scheme.primary,
                                ),
                                title: Text(
                                  note.title.isNotEmpty
                                      ? note.title
                                      : 'Untitled',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedAdd01,
                                    size: 20,
                                    color: scheme.primary,
                                  ),
                                  tooltip: 'Tag note',
                                  onPressed: () => _tagNote(note.id),
                                ),
                                onTap: () => _tagNote(note.id),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
