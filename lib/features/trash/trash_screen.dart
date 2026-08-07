import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../data/repositories/note_repository.dart';

/// Trash screen — lists soft-deleted notes with restore / permanent delete.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  List<_DeletedNote> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = NoteRepository(db);
    final deleted = await repo.getDeletedNotes();
    if (mounted) {
      setState(() {
        _notes = deleted
            .map((n) => _DeletedNote(id: n.id, title: n.title, deletedAt: n.deletedAt))
            .toList();
        _loading = false;
      });
    }
  }

  Future<void> _restore(String id) async {
    final db = ref.read(databaseProvider);
    final repo = NoteRepository(db);
    await repo.restore(id);
    await _load();
  }

  Future<void> _permanentDelete(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanently delete?'),
        content: Text('"$title" will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      final repo = NoteRepository(db);
      await repo.permanentlyDelete(id);
      await _load();
    }
  }

  Future<void> _emptyTrash() async {
    if (_notes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empty trash?'),
        content: Text('Permanently delete all ${_notes.length} notes in trash? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      final repo = NoteRepository(db);
      for (final note in _notes) {
        await repo.permanentlyDelete(note.id);
      }
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (_notes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Empty trash',
              onPressed: _emptyTrash,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 64,
                        color: scheme.onSurface.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Trash is empty',
                        style: TextStyle(
                          fontSize: 18,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final age = _formatAge(note.deletedAt);
                    return ListTile(
                      leading: Icon(
                        Icons.description_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                      title: Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Deleted $age',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore_from_trash_outlined),
                            tooltip: 'Restore',
                            onPressed: () => _restore(note.id),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_forever_outlined,
                              color: scheme.error,
                            ),
                            tooltip: 'Delete permanently',
                            onPressed: () =>
                                _permanentDelete(note.id, note.title),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _formatAge(DateTime? deletedAt) {
    if (deletedAt == null) return 'recently';
    final diff = DateTime.now().difference(deletedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

class _DeletedNote {
  const _DeletedNote({
    required this.id,
    required this.title,
    this.deletedAt,
  });

  final String id;
  final String title;
  final DateTime? deletedAt;
}
