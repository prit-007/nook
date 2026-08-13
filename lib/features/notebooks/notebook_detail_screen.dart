import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/masked_reveal.dart';
import '../../core/widgets/masked_reveal_text.dart';
import '../../core/widgets/parallax_card.dart';
import '../../data/database.dart';
import '../../data/repositories/notebook_repository.dart';
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
      body: _loading
          ? Center(child: CircularProgressIndicator(color: seedColor))
          : _notes.isEmpty
              ? const EmptyState(
                  icon: Icons.notes_outlined,
                  title: 'No notes in this collection',
                  subtitle: 'Create a note and assign it here.',
                  animate: false,
                )
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    DockSafeArea.bottomOf(context) + 72,
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
