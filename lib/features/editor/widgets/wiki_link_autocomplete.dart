import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/providers/database_provider.dart';
import '../../../data/database.dart';
import '../../../data/repositories/note_repository.dart';
import '../editor_toolbar.dart';

/// Parsed `[[query` match immediately before the cursor.
class WikiLinkMatch {
  const WikiLinkMatch({
    required this.startOffset,
    required this.query,
  });

  final int startOffset;
  final String query;

  /// Total prefix length (`[[` + query) to delete when inserting a link.
  int get prefixLength => 2 + query.length;
}

/// Scans backwards from [cursorOffset] in [text] for an unclosed `[[`.
///
/// Returns `null` if no `[[` precedes the cursor, or if `]]` / `\n` appears
/// between `[[` and [cursorOffset].
WikiLinkMatch? extractWikiLinkQuery(String text, int cursorOffset) {
  if (cursorOffset < 2 || cursorOffset > text.length) return null;
  final beforeCursor = text.substring(0, cursorOffset);
  final openIndex = beforeCursor.lastIndexOf('[[');
  if (openIndex == -1) return null;

  final between = beforeCursor.substring(openIndex + 2);
  if (between.contains(']]') || between.contains('\n')) return null;

  return WikiLinkMatch(startOffset: openIndex, query: between);
}

/// Filters and ranks candidate [notes] for a `[[wiki]]` [query].
List<Note> filterWikiLinkCandidates(
  List<Note> notes, {
  required String query,
  String? excludeNoteId,
  int limit = 6,
}) {
  final needle = query.trim().toLowerCase();
  final candidates = notes.where((n) {
    if (n.deleted) return false;
    if (excludeNoteId != null && n.id == excludeNoteId) return false;
    if (needle.isEmpty) return true;
    return n.title.toLowerCase().contains(needle);
  }).toList();

  candidates.sort((a, b) {
    if (needle.isNotEmpty) {
      final aStarts = a.title.toLowerCase().startsWith(needle);
      final bStarts = b.title.toLowerCase().startsWith(needle);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  });

  if (candidates.length > limit) {
    return candidates.sublist(0, limit);
  }
  return candidates;
}

/// Inline `[[wiki]]` link autocomplete bar layered over the editor body.
///
/// Listens to [editorState.selectionNotifier] and [editorState.transactionStream]
/// so typing `[[` followed by any filter text surfaces matching notes without
/// interrupting typing with a modal dialog.
class WikiLinkAutocomplete extends ConsumerStatefulWidget {
  const WikiLinkAutocomplete({
    super.key,
    required this.editorState,
    required this.child,
    this.currentNoteId,
    this.readOnly = false,
    this.onBrowseAll,
  });

  final EditorState editorState;
  final Widget child;
  final String? currentNoteId;
  final bool readOnly;
  final VoidCallback? onBrowseAll;

  @override
  ConsumerState<WikiLinkAutocomplete> createState() =>
      _WikiLinkAutocompleteState();
}

class _WikiLinkAutocompleteState extends ConsumerState<WikiLinkAutocomplete> {
  StreamSubscription<dynamic>? _txSub;
  WikiLinkMatch? _activeMatch;
  List<Note> _cachedNotes = const [];
  bool _loadedNotes = false;
  bool _dismissed = false;
  int? _dismissedStartOffset;

  @override
  void initState() {
    super.initState();
    widget.editorState.selectionNotifier.addListener(_onEditorChanged);
    _txSub = widget.editorState.transactionStream.listen((_) {
      _onEditorChanged();
    });
    _onEditorChanged();
  }

  @override
  void didUpdateWidget(covariant WikiLinkAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorState != widget.editorState) {
      oldWidget.editorState.selectionNotifier.removeListener(_onEditorChanged);
      _txSub?.cancel();
      widget.editorState.selectionNotifier.addListener(_onEditorChanged);
      _txSub = widget.editorState.transactionStream.listen((_) {
        _onEditorChanged();
      });
      _onEditorChanged();
    }
  }

  @override
  void dispose() {
    widget.editorState.selectionNotifier.removeListener(_onEditorChanged);
    _txSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureNotesLoaded() async {
    if (_loadedNotes) return;
    _loadedNotes = true;
    try {
      final db = ref.read(databaseProvider);
      final notes = await NoteRepository(db).getAllNotes();
      if (mounted) {
        setState(() => _cachedNotes = notes);
      }
    } catch (_) {
      _loadedNotes = false;
    }
  }

  void _onEditorChanged() {
    if (widget.readOnly) {
      if (_activeMatch != null && mounted) {
        setState(() => _activeMatch = null);
      }
      return;
    }
    final selection = widget.editorState.selection;
    if (selection == null || !selection.isCollapsed) {
      if (_activeMatch != null && mounted) {
        setState(() => _activeMatch = null);
      }
      return;
    }
    final node = widget.editorState.getNodeAtPath(selection.start.path);
    final text = node?.delta?.toPlainText();
    if (text == null) {
      if (_activeMatch != null && mounted) {
        setState(() => _activeMatch = null);
      }
      return;
    }

    final match = extractWikiLinkQuery(text, selection.start.offset);
    if (match == null) {
      _dismissed = false;
      _dismissedStartOffset = null;
      if (_activeMatch != null && mounted) {
        setState(() => _activeMatch = null);
      }
      return;
    }

    if (_dismissed && _dismissedStartOffset == match.startOffset) {
      return;
    }
    _dismissed = false;
    _dismissedStartOffset = null;

    unawaited(_ensureNotesLoaded());
    if (mounted) {
      setState(() => _activeMatch = match);
    }
  }

  void _selectNote(Note note, WikiLinkMatch match) {
    HapticFeedback.selectionClick();
    insertNoteLinkAtSelection(
      widget.editorState,
      noteId: note.id,
      title: note.title,
      deletePrefixLength: match.prefixLength,
    );
    setState(() {
      _activeMatch = null;
      _dismissed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final match = _activeMatch;
    if (match == null || widget.readOnly) {
      return widget.child;
    }

    final scheme = Theme.of(context).colorScheme;
    final candidates = filterWikiLinkCandidates(
      _cachedNotes,
      query: match.query,
      excludeNoteId: widget.currentNoteId,
    );

    return Column(
      children: [
        Expanded(child: widget.child),
        Material(
          color: scheme.surfaceContainerHigh,
          elevation: 4,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedLink01,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        match.query.isEmpty
                            ? 'Link to note'
                            : 'Link matching "${match.query}"',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (widget.onBrowseAll != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _dismissed = true;
                            _dismissedStartOffset = match.startOffset;
                            _activeMatch = null;
                          });
                          widget.onBrowseAll!();
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('Browse'),
                      ),
                    IconButton(
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        size: 16,
                      ),
                      tooltip: 'Dismiss suggestions',
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 36),
                      onPressed: () {
                        setState(() {
                          _dismissed = true;
                          _dismissedStartOffset = match.startOffset;
                          _activeMatch = null;
                        });
                      },
                    ),
                  ],
                ),
                if (candidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'No matching notes',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final note in candidates)
                          Padding(
                            padding: const EdgeInsets.only(right: 8, top: 4),
                            child: ActionChip(
                              avatar: HugeIcon(
                                icon: HugeIcons.strokeRoundedNote01,
                                size: 16,
                                color: scheme.primary,
                              ),
                              label: Text(
                                note.title.trim().isEmpty
                                    ? 'Untitled'
                                    : note.title.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () => _selectNote(note, match),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
