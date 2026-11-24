import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

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
        color: scheme.surface,
        child: const Center(
          child: EmptyState(
            icon: HugeIcons.strokeRoundedBookOpen01,
            title: 'Select a notebook',
            subtitle: 'Choose a notebook from the left pane to view notes.',
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
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: seedColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_notebookName.contains('/'))
                        Text(
                          _notebookName
                              .split('/')
                              .sublist(0, _notebookName.split('/').length - 1)
                              .map((s) => s.trim())
                              .join(' › '),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                            letterSpacing: 0.2,
                          ),
                        ),
                      Text(
                        _notebookName.isEmpty
                            ? 'Notebook'
                            : (_notebookName.contains('/')
                                ? _notebookName.split('/').last.trim()
                                : _notebookName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_notes.length} ${_notes.length == 1 ? 'note' : 'notes'}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.15),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: seedColor))
                : _notes.isEmpty
                    ? const EmptyState(
                        icon: HugeIcons.strokeRoundedNotebook01,
                        title: 'No notes in this notebook',
                        subtitle: 'Create a note and assign it here.',
                        animate: false,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _notes.length,
                        itemBuilder: (context, index) => NoteCard(
                          note: _notes[index],
                          // rendered in the NotebookDetailPane (kept alive in
                          // the NotebooksScreen IndexedStack) never collides.
                          heroTag:
                              'nb-${widget.notebookId}-${_notes[index].id}',
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
