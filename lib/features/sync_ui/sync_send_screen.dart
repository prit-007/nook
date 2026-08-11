import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/tables/notes.dart';

/// Sync send screen — note selection + device discovery.
class SyncSendScreen extends ConsumerStatefulWidget {
  const SyncSendScreen({super.key});

  @override
  ConsumerState<SyncSendScreen> createState() => _SyncSendScreenState();
}

class _SyncSendScreenState extends ConsumerState<SyncSendScreen> {
  final Set<String> _selectedNoteIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Notes'),
        actions: [
          if (_selectedNoteIds.isNotEmpty)
            TextButton(
              onPressed: () {
                // TODO: Start discovery and send
                context.push('/sync/send');
              },
              child: Text('Send (${_selectedNoteIds.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Note>>(
              future: (db.select(db.notes)
                    ..where((t) => t.deleted.equals(false))
                    ..orderBy([
                      (t) => OrderingTerm.desc(t.pinned),
                      (t) => OrderingTerm.desc(t.updatedAt),
                    ]))
                  .get()
                  .then((notes) {
                if (_searchQuery.isEmpty) return notes;
                final q = _searchQuery.toLowerCase();
                return notes.where((n) =>
                    n.title.toLowerCase().contains(q) ||
                    (n.plainText?.toLowerCase().contains(q) == true)).toList();
              }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notes = snapshot.data ?? [];

                if (notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.note_add_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notes to sync',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final isSelected = _selectedNoteIds.contains(note.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedNoteIds.add(note.id);
                          } else {
                            _selectedNoteIds.remove(note.id);
                          }
                        });
                      },
                      title: Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _noteTypeLabel(note.type),
                        style: theme.textTheme.bodySmall,
                      ),
                      secondary: Icon(_noteTypeIcon(note.type)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _noteTypeLabel(NoteType type) {
    switch (type) {
      case NoteType.text:
        return 'Text note';
      case NoteType.checklist:
        return 'Checklist';
      case NoteType.doodle:
        return 'Doodle';
      case NoteType.mixed:
        return 'Mixed';
    }
  }

  IconData _noteTypeIcon(NoteType type) {
    switch (type) {
      case NoteType.text:
        return Icons.note;
      case NoteType.checklist:
        return Icons.checklist;
      case NoteType.doodle:
        return Icons.brush;
      case NoteType.mixed:
        return Icons.dynamic_feed;
    }
  }
}
