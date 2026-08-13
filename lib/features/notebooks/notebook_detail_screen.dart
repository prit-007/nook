import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/masked_reveal.dart';
import '../../core/widgets/masked_reveal_text.dart';
import '../../core/widgets/parallax_card.dart';
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

    if (!mounted) return;
    setState(() {
      _notes = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = NookColors.parseHex(_notebookColor);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      appBar: AppBar(
        title: MaskedRevealText(
          _notebookName.isEmpty ? 'Notebook' : _notebookName,
        ),
        iconTheme: IconThemeData(color: seedColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const EmptyState(
                  icon: Icons.notes_outlined,
                  title: 'No notes in this notebook',
                  subtitle: 'Create a note and assign it to this notebook',
                  animate: false,
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    DockSafeArea.bottomOf(context) + 72,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.75,
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
                          milliseconds: (index * 70).clamp(0, 500),
                        ),
                        child: card,
                      ),
                    );
                  },
                ),
    );
  }
}
