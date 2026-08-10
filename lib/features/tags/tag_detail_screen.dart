import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database.dart';
import '../../data/repositories/tag_repository.dart';
import '../home/widgets/note_card.dart';

/// Shows notes filtered by tag.
class TagDetailScreen extends ConsumerStatefulWidget {
  const TagDetailScreen({super.key, required this.tagId});

  final String tagId;

  @override
  ConsumerState<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends ConsumerState<TagDetailScreen> {
  String _tagName = '';
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
    }

    final results = await tagRepo.getNotesForTag(widget.tagId);

    if (!mounted) return;
    setState(() {
      _notes = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tagName.isEmpty ? 'Tag' : _tagName),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const EmptyState(
                  icon: Icons.notes_outlined,
                  title: 'No notes with this tag',
                  subtitle: 'Tag notes from the editor options menu',
                  animate: false,
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
                  itemBuilder: (context, index) => NoteCard(
                    note: _notes[index],
                    onTap: () => context.push('/note/${_notes[index].id}'),
                  ),
                ),
    );
  }
}
