import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hugeicons/hugeicons.dart';
import '../../core/providers/database_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/masked_reveal.dart';
import '../../core/widgets/masked_reveal_text.dart';
import '../../core/widgets/parallax_card.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/tables/notes.dart';
import '../home/widgets/note_card.dart';

class NotebookDetailScreen extends ConsumerStatefulWidget {
  const NotebookDetailScreen({super.key, required this.notebookId});

  final String notebookId;

  @override
  ConsumerState<NotebookDetailScreen> createState() =>
      _NotebookDetailScreenState();
}

class _NotebookDetailScreenState extends ConsumerState<NotebookDetailScreen> {
  String _notebookName = '';
  String _notebookColor = '#FF5722';
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final nbRepo = NotebookRepository(db);

    final nb = await nbRepo.getNotebookById(widget.notebookId);
    if (nb != null) {
      _notebookName = nb.name;
      _notebookColor = nb.colorSeed;
    }

    final results = await (db.select(db.notes)
          ..where((t) =>
              t.notebookId.equals(widget.notebookId) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();

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
      builder: (_) => _AddNotesToNotebookSheet(
        notebookId: widget.notebookId,
        onNotesAdded: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = NookColors.parseHex(_notebookColor);
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      appBar: AppBar(
        title: MaskedRevealText(
          _notebookName.isEmpty ? 'Notebook' : _notebookName,
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(color: seedColor),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-notebook-detail',
        onPressed: _showAddNotesSheet,
        tooltip: 'Add notes',
        backgroundColor: seedColor,
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          size: 24,
          color: scheme.onPrimary,
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: seedColor))
          : _notes.isEmpty
              ? const EmptyState(
                  icon: HugeIcons.strokeRoundedNotebook01,
                  title: 'No notes in this collection',
                  subtitle: 'Create a note and assign it here.',
                  animate: false,
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    DockSafeArea.bottomOf(context) + 16,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final card = NoteCard(
                      note: _notes[index],
                      onTap: () => context.push('/note/${_notes[index].id}'),
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
                ),
    );
  }
}

class _AddNotesToNotebookSheet extends ConsumerStatefulWidget {
  const _AddNotesToNotebookSheet({
    required this.notebookId,
    this.onNotesAdded,
  });

  final String notebookId;
  final VoidCallback? onNotesAdded;

  @override
  ConsumerState<_AddNotesToNotebookSheet> createState() =>
      _AddNotesToNotebookSheetState();
}

class _AddNotesToNotebookSheetState
    extends ConsumerState<_AddNotesToNotebookSheet> {
  List<Note> _unassignedNotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final results = await (db.select(db.notes)
          ..where((t) => t.notebookId.isNull() & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    if (mounted) {
      setState(() {
        _unassignedNotes = results;
        _loading = false;
      });
    }
  }

  Future<void> _assignNote(String noteId) async {
    final db = ref.read(databaseProvider);
    final repo = NoteRepository(db);
    await repo.updateNote(noteId, notebookId: widget.notebookId);
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
                'Add notes to notebook',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Select unassigned notes to add them here.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _unassignedNotes.isEmpty
                        ? Center(
                            child: Text(
                              'No unassigned notes found',
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _unassignedNotes.length,
                            itemBuilder: (context, index) {
                              final note = _unassignedNotes[index];
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
                                  tooltip: 'Add to notebook',
                                  onPressed: () => _assignNote(note.id),
                                ),
                                onTap: () => _assignNote(note.id),
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
