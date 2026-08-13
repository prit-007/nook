import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/selection_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/database.dart';
import '../../home/widgets/note_card.dart';

/// Right-hand pane of the notebooks master-detail layout on tablets.
///
/// Shows the notes of the notebook selected in the left-hand grid. Unlike
/// [NotebookDetailScreen] it renders no Scaffold or AppBar — it is embedded
/// beside the notebooks list.
class NotebookDetailPane extends ConsumerWidget {
  const NotebookDetailPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebookId = ref.watch(selectedNotebookIdProvider);
    final scheme = Theme.of(context).colorScheme;

    if (notebookId == null) {
      return ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: const Center(
          child: EmptyState(
            icon: LucideIcons.bookOpen,
            title: 'Select a notebook',
            subtitle: 'Choose a notebook to browse its notes.',
            animate: false,
          ),
        ),
      );
    }

    return _NotebookNotesPane(notebookId: notebookId);
  }
}

class _NotebookNotesPane extends ConsumerStatefulWidget {
  const _NotebookNotesPane({required this.notebookId});

  final String notebookId;

  @override
  ConsumerState<_NotebookNotesPane> createState() => _NotebookNotesPaneState();
}

class _NotebookNotesPaneState extends ConsumerState<_NotebookNotesPane> {
  String _notebookName = '';
  String _notebookColor = '#FF5722';
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _NotebookNotesPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notebookId != widget.notebookId) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final nb = await (db.select(db.notebooks)
          ..where((t) => t.id.equals(widget.notebookId)))
        .getSingleOrNull();
    final results = await (db.select(db.notes)
          ..where((t) =>
              t.notebookId.equals(widget.notebookId) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();

    if (!mounted) return;
    setState(() {
      _notebookName = nb?.name ?? '';
      _notebookColor = nb?.colorSeed ?? '#FF5722';
      _notes = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = NookColors.parseHex(_notebookColor);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _notebookName.isEmpty ? 'Notebook' : _notebookName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: seedColor,
                    ),
                  ),
                ),
                Text(
                  '${_notes.length} note${_notes.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                    ? const EmptyState(
                        icon: Icons.notes_outlined,
                        title: 'No notes in this notebook',
                        subtitle:
                            'Create a note and assign it to this notebook',
                        animate: false,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _notes.length,
                        itemBuilder: (context, index) => NoteCard(
                          note: _notes[index],
                          onTap: () =>
                              context.push('/note/${_notes[index].id}'),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
