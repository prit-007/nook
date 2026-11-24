import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/providers/database_provider.dart';
import '../../../data/database.dart';
import '../../../data/repositories/note_link_repository.dart';

/// An interactive panel displaying incoming backlinks and related notes
/// (notes in the same notebook or referencing this note).
class BacklinksPanel extends ConsumerStatefulWidget {
  const BacklinksPanel({
    super.key,
    required this.note,
    this.onSelectNote,
  });

  final Note note;
  final ValueChanged<String>? onSelectNote;

  @override
  ConsumerState<BacklinksPanel> createState() => _BacklinksPanelState();
}

class _BacklinksPanelState extends ConsumerState<BacklinksPanel> {
  List<NoteLinkHit> _backlinks = [];
  List<Note> _relatedNotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BacklinksPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.id != widget.note.id) {
      _load();
    }
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final linkRepo = NoteLinkRepository(db);

    final backlinks = await linkRepo.incomingTo(widget.note.id);

    List<Note> related = [];
    if (widget.note.notebookId != null) {
      final query = db.select(db.notes)
        ..where((t) =>
            t.notebookId.equals(widget.note.notebookId!) &
            t.id.equals(widget.note.id).not() &
            t.deleted.equals(false))
        ..limit(5);
      related = await query.get();
    }

    if (!mounted) return;
    setState(() {
      _backlinks = backlinks;
      _relatedNotes = related;
      _loading = false;
    });
  }

  void _navigateTo(String noteId) {
    if (widget.onSelectNote != null) {
      widget.onSelectNote!(noteId);
    } else {
      context.push('/note/$noteId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_backlinks.isEmpty && _relatedNotes.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedLinkSquare01,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No incoming backlinks',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_backlinks.isNotEmpty) ...[
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedLink01,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Referenced in ${_backlinks.length} note${_backlinks.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final hit in _backlinks)
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: HugeIcon(
                    icon: HugeIcons.strokeRoundedNote01,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    hit.title.isNotEmpty ? hit.title : 'Untitled',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () => _navigateTo(hit.noteId),
                ),
              ),
          ],
          if (_relatedNotes.isNotEmpty) ...[
            if (_backlinks.isNotEmpty) const Divider(height: 20),
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedNotebook01,
                  size: 18,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Related notes in notebook',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final note in _relatedNotes)
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: HugeIcon(
                    icon: HugeIcons.strokeRoundedNote02,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    note.title.isNotEmpty ? note.title : 'Untitled',
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () => _navigateTo(note.id),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
