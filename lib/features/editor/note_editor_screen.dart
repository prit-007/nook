import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';
import 'widgets/note_options_sheet.dart';

/// Note editor screen — AppFlowy Editor integration with autosave.
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.notebookId,
    this.type,
  });

  final String? noteId;
  final String? notebookId;
  final String? type;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  EditorState? _editorState;
  Note? _note;
  String _title = '';
  bool _pinned = false;
  bool _loading = true;
  bool _saving = false;
  String? _colorSeed;
  String? _notebookId;
  Timer? _autosaveTimer;
  AppDatabase? _db;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _db = ref.read(databaseProvider);
    final repo = NoteRepository(_db!);

    if (widget.noteId != null) {
      // Load existing note
      final note = await repo.getNoteById(widget.noteId!);
      if (note == null) {
        if (mounted) context.pop();
        return;
      }
      _note = note;
      _title = note.title;
      _pinned = note.pinned;
      _colorSeed = note.colorSeed;
      _notebookId = note.notebookId;

      // Build editor from stored JSON or blank
      if (note.deltaContent != null && note.deltaContent!.isNotEmpty) {
        try {
          final json =
              Map<String, dynamic>.from(jsonDecode(note.deltaContent!) as Map);
          final document = Document.fromJson(json);
          _editorState = EditorState(document: document);
        } catch (e) {
          _editorState = EditorState.blank(withInitialText: true);
        }
      } else {
        _editorState = EditorState.blank(withInitialText: true);
        // Pre-populate with title if exists
        if (note.title.isNotEmpty) {
          final transaction = _editorState!.transaction;
          final nodes = _editorState!.document.root.children;
          if (nodes.isNotEmpty) {
            final firstNode = nodes.first;
            if (firstNode.delta != null && firstNode.delta!.isEmpty) {
              transaction.insertText(firstNode, 0, note.title);
              await _editorState!.apply(transaction);
            }
          }
        }
      }
    } else {
      // Create new note
      final noteType = NoteType.values.firstWhere(
        (t) => t.name == widget.type,
        orElse: () => NoteType.text,
      );
      final note = await repo.createNote(
        title: '',
        type: noteType,
        deviceOriginId: 'local',
        notebookId: widget.notebookId,
      );
      _note = note;
      _editorState = EditorState.blank(withInitialText: true);
    }

    // Listen to document changes for autosave
    _editorState!.transactionStream.listen((_) {
      _scheduleAutosave();
    });

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    if (_note == null || _editorState == null || _saving) return;

    _saving = true;
    try {
      final repo = NoteRepository(_db!);

      // Extract plain text from document
      final nodes = _editorState!.document.root.children;
      String plainText = '';
      for (final node in nodes) {
        if (node.delta != null) {
          for (final op in node.delta!.toList()) {
            if (op is TextInsert) {
              plainText += op.text;
            }
          }
          plainText += '\n';
        }
      }
      plainText = plainText.trim();

      // Derive title from first line or existing title
      final derivedTitle = plainText.split('\n').firstOrNull ?? _title;
      if (derivedTitle != _title && derivedTitle.isNotEmpty) {
        _title = derivedTitle;
        await repo.updateNote(_note!.id, title: _title);
      }

      await repo.updateContent(
        _note!.id,
        deltaContent: jsonEncode(_editorState!.document.toJson()),
        plainText: plainText,
      );
    } finally {
      _saving = false;
    }
  }

  Future<void> _togglePin() async {
    if (_note == null) return;
    final repo = NoteRepository(_db!);
    final newPinned = !_pinned;
    await repo.updateNote(_note!.id, pinned: newPinned);
    setState(() => _pinned = newPinned);
  }

  Future<void> _deleteNote() async {
    if (_note == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Move this note to trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final repo = NoteRepository(_db!);
      await repo.softDelete(_note!.id);
      if (mounted) GoRouter.of(context).pop();
    }
  }

  Future<void> _showNoteOptions() async {
    if (_note == null) return;
    final repo = NoteRepository(_db!);

    await NoteOptionsSheet.show(
      context,
      noteId: _note!.id,
      currentNotebookId: _notebookId,
      currentColorSeed: _colorSeed,
      onNotebookChanged: (id) async {
        _notebookId = id;
        await repo.updateNote(_note!.id, notebookId: id);
      },
      onColorChanged: (color) async {
        _colorSeed = color;
        await repo.updateNote(_note!.id, colorSeed: color);
      },
    );
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    // Save one final time before disposing
    _save();
    _editorState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_editorState == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Failed to load note')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            final nav = GoRouter.of(context);
            await _save();
            if (mounted) nav.pop();
          },
        ),
        title: Text(widget.noteId != null ? 'Edit Note' : 'New Note'),
        actions: [
          IconButton(
            icon: Icon(
              _pinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
            onPressed: _togglePin,
            tooltip: _pinned ? 'Unpin' : 'Pin',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteNote,
            tooltip: 'Delete',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showNoteOptions,
            tooltip: 'Note options',
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: AppFlowyEditor(
        editorState: _editorState!,
        autoFocus: true,
      ),
    );
  }
}
