import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';

/// Screen showing only locked notes — requires biometric re-prompt
/// to view individual notes.
class LockedNotesScreen extends ConsumerStatefulWidget {
  const LockedNotesScreen({super.key});

  @override
  ConsumerState<LockedNotesScreen> createState() => _LockedNotesScreenState();
}

class _LockedNotesScreenState extends ConsumerState<LockedNotesScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final notes = await NoteRepository(db).getLockedNotes();
    if (mounted) {
      setState(() {
        _notes = notes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locked Notes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const EmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'No locked notes',
                  subtitle: 'Lock notes from the editor options menu',
                  animate: false,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return ListTile(
                      leading: Icon(
                        Icons.lock_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        note.title.isNotEmpty ? note.title : 'Untitled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Locked',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () {
                        context.push('/note/${note.id}');
                      },
                    );
                  },
                ),
    );
  }
}
