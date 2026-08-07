import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/notebook_repository.dart';
import '../home/widgets/note_card.dart';

/// Shows notes filtered by notebook.
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

    setState(() {
      _notes = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = Color(
      int.parse('FF${_notebookColor.replaceFirst('#', '')}', radix: 16),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_notebookName.isEmpty ? 'Notebook' : _notebookName),
        iconTheme: IconThemeData(color: seedColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Text(
                    'No notes in this notebook',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) =>
                      NoteCard(note: _notes[index]),
                ),
    );
  }
}
