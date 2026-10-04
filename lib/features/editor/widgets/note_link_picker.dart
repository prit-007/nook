import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/providers/database_provider.dart';
import '../../../data/database.dart';
import '../../../data/repositories/note_link_repository.dart';

/// Result of the note-link picker.
class NoteLinkPick {
  const NoteLinkPick({required this.noteId, required this.title});

  final String noteId;
  final String title;
}

/// Modal search UI for picking a note to link to.
Future<NoteLinkPick?> showNoteLinkPicker(
  BuildContext context, {
  String? excludeNoteId,
}) {
  return showModalBottomSheet<NoteLinkPick>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _NoteLinkPickerSheet(excludeNoteId: excludeNoteId),
  );
}

class _NoteLinkPickerSheet extends ConsumerStatefulWidget {
  const _NoteLinkPickerSheet({this.excludeNoteId});

  final String? excludeNoteId;

  @override
  ConsumerState<_NoteLinkPickerSheet> createState() =>
      _NoteLinkPickerSheetState();
}

class _NoteLinkPickerSheetState extends ConsumerState<_NoteLinkPickerSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<Note> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search('');
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final db = ref.read(databaseProvider);
    final notes = await NoteLinkRepository(db).searchNotesForLinkPicker(
      query,
      excludeId: widget.excludeNoteId,
    );
    if (!mounted) return;
    setState(() {
      _results = notes;
      _loading = false;
    });
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(q));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link to note',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Search notes...',
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: _onChanged,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          'No notes found',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final note = _results[index];
                          return ListTile(
                            leading: HugeIcon(
                              icon: HugeIcons.strokeRoundedNote01,
                              size: 20,
                              color: scheme.primary,
                            ),
                            title: Text(
                              note.title.isEmpty ? 'Untitled' : note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.pop(
                              context,
                              NoteLinkPick(noteId: note.id, title: note.title),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

/// Shows outgoing + incoming links for a note.
Future<void> showNoteLinksSheet(
  BuildContext context, {
  required String noteId,
  required String noteTitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _NoteLinksSheet(noteId: noteId, noteTitle: noteTitle),
  );
}

class _NoteLinksSheet extends ConsumerStatefulWidget {
  const _NoteLinksSheet({required this.noteId, required this.noteTitle});

  final String noteId;
  final String noteTitle;

  @override
  ConsumerState<_NoteLinksSheet> createState() => _NoteLinksSheetState();
}

class _NoteLinksSheetState extends ConsumerState<_NoteLinksSheet> {
  List<NoteLinkHit> _outgoing = [];
  List<NoteLinkHit> _incoming = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = NoteLinkRepository(db);
    final outgoing = await repo.outgoingFrom(widget.noteId);
    final incoming = await repo.incomingTo(widget.noteId);
    if (!mounted) return;
    setState(() {
      _outgoing = outgoing;
      _incoming = incoming;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: _loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Linked notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.noteTitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                if (_outgoing.isEmpty && _incoming.isEmpty)
                  Text(
                    'No links yet. Use “Link to note” in the editor slash menu '
                    'or options to connect notes.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  )
                else ...[
                  if (_outgoing.isNotEmpty) ...[
                    Text(
                      'Links to ${_outgoing.length} note(s)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    for (final hit in _outgoing)
                      _LinkRow(hit: hit, scheme: scheme, incoming: false),
                  ],
                  if (_incoming.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Referenced in ${_incoming.length} note(s)',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    for (final hit in _incoming)
                      _LinkRow(hit: hit, scheme: scheme, incoming: true),
                  ],
                ],
              ],
            ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.hit,
    required this.scheme,
    required this.incoming,
  });

  final NoteLinkHit hit;
  final ColorScheme scheme;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final title = incoming ? hit.title : hit.linkedTitle;
    final subtitle = incoming
        ? (hit.linkedDeleted ? 'Missing note' : hit.linkedTitle)
        : (hit.linkedDeleted ? 'Missing note' : 'Note');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: HugeIcon(
        icon: hit.linkedDeleted
            ? HugeIcons.strokeRoundedAlert01
            : HugeIcons.strokeRoundedLink01,
        size: 20,
        color: hit.linkedDeleted ? scheme.error : scheme.primary,
      ),
      title: Text(title.isEmpty ? 'Untitled' : title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: hit.linkedDeleted ? scheme.error : scheme.onSurfaceVariant,
            ),
      ),
      onTap: () {
        final targetId = incoming ? hit.linkedNoteId : hit.noteId;
        Navigator.pop(context);
        context.push('/note/$targetId');
      },
    );
  }
}
