import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';

/// Displays long-term archived notes (separate from the 30-day Trash Bin).
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  List<Note> _notes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final archived = await NoteRepository(db).getArchivedNotes();
    if (!mounted) return;
    setState(() {
      _notes = archived;
      _loading = false;
    });
  }

  Future<void> _unarchive(Note note) async {
    unawaited(HapticFeedback.selectionClick());
    final db = ref.read(databaseProvider);
    await NoteRepository(db).unarchiveNote(note.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedArchive,
                          size: 48,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No archived notes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Archive inactive notes to keep Home focused without deleting them.',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          note.title.trim().isEmpty
                              ? 'Untitled'
                              : note.title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: (note.plainText ?? '').trim().isEmpty
                            ? null
                            : Text(
                                note.plainText!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                        trailing: IconButton(
                          tooltip: 'Unarchive',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedUndo02,
                            size: 20,
                            color: scheme.primary,
                          ),
                          onPressed: () => _unarchive(note),
                        ),
                        onTap: () => context.push('/note/${note.id}'),
                      ),
                    );
                  },
                ),
    );
  }
}
