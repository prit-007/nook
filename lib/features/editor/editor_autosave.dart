import 'dart:async';
import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import '../../core/providers/talker_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/revision_repository.dart';

/// Pre-captured editor content for a best-effort dispose or background save.
class PersistSnapshot {
  const PersistSnapshot({
    required this.noteId,
    required this.deltaJson,
    required this.plainText,
    required this.db,
    this.title,
  });

  final String noteId;
  final String? title;
  final String deltaJson;
  final String plainText;
  final AppDatabase db;
}

/// Controller managing debounced autosave, revision snapshots, and safe dispose persistence.
class EditorAutosaveController {
  Timer? _autosaveTimer;
  bool _saving = false;
  bool _saveQueued = false;
  bool _dirty = false;

  /// Incremented whenever [isDirty] or [isSaving] changes so the editor app
  /// bar can display a persistent quiet "Saved" / "Saving..." indicator.
  final ValueNotifier<int> statusVersion = ValueNotifier<int>(0);

  bool get isSaving => _saving;
  bool get isDirty => _dirty;

  void _notifyStatus() {
    statusVersion.value++;
  }

  void markDirty() {
    if (_dirty) return;
    _dirty = true;
    _notifyStatus();
  }

  void markClean() {
    if (!_dirty) return;
    _dirty = false;
    _notifyStatus();
  }

  /// Cancels any scheduled autosave timer.
  void cancelTimer() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
  }

  /// Schedules a debounced save invocation after [delay] (default 600ms).
  void scheduleAutosave({
    required Future<void> Function() onSave,
    Duration delay = const Duration(milliseconds: 600),
  }) {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(delay, () => unawaited(onSave()));
  }

  /// Serializes the editor state to a [PersistSnapshot] without async gaps.
  static PersistSnapshot snapshotContent({
    required EditorState editorState,
    required String currentTitle,
    required String noteId,
    required AppDatabase db,
  }) {
    final nodes = editorState.document.root.children;
    String plainText = '';
    for (final node in nodes) {
      if (node.delta != null) {
        for (final op in node.delta!.toList()) {
          if (op is TextInsert) plainText += op.text;
        }
        plainText += '\n';
      }
    }
    plainText = plainText.trim();
    final derivedTitle = plainText.split('\n').firstOrNull ?? currentTitle;
    return PersistSnapshot(
      noteId: noteId,
      title: derivedTitle != currentTitle ? derivedTitle : null,
      deltaJson: jsonEncode(editorState.document.toJson()),
      plainText: plainText,
      db: db,
    );
  }

  /// Writes a pre-captured snapshot to the database, ignoring errors.
  static Future<void> persistSnapshot(PersistSnapshot snapshot) async {
    try {
      final repo = NoteRepository(snapshot.db);
      if (snapshot.title != null) {
        await repo.updateNote(snapshot.noteId, title: snapshot.title!);
      }
      await repo.updateContent(
        snapshot.noteId,
        deltaContent: snapshot.deltaJson,
        plainText: snapshot.plainText,
      );
      nookLog(
        NookLogKey.editor,
        'Dispose-save persisted: ${snapshot.noteId}',
        LogLevel.info,
      );
    } catch (e) {
      nookLog(
        NookLogKey.editor,
        'Dispose-save failed for ${snapshot.noteId}: $e',
        LogLevel.error,
      );
    }
  }

  /// Executes a full save of the editor state, creating a revision snapshot and
  /// updating the database. Calls [onSaved] on completion.
  Future<void> save({
    required EditorState? editorState,
    required Note? note,
    required AppDatabase? db,
    required String currentTitle,
    required bool isDisposed,
    required void Function(String derivedTitle, Note updatedNote) onSaved,
  }) async {
    if (isDisposed || note == null || editorState == null || db == null) return;
    if (!_dirty) return;
    if (_saving) {
      _saveQueued = true;
      return;
    }

    _saving = true;
    try {
      final repo = NoteRepository(db);

      final nodes = editorState.document.root.children;
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

      final derivedTitle = plainText.split('\n').firstOrNull ?? currentTitle;
      if (derivedTitle != currentTitle && derivedTitle.isNotEmpty) {
        await repo.updateNote(note.id, title: derivedTitle);
      }

      final deltaJson = jsonEncode(editorState.document.toJson());
      await repo.updateContent(
        note.id,
        deltaContent: deltaJson,
        plainText: plainText,
      );

      // Version history: time-bucketed autosave snapshots (local-only).
      try {
        final nowSnapshot = DateTime.now();
        await RevisionRepository(db).maybeSnapshot(
          noteId: note.id,
          title: derivedTitle.isNotEmpty ? derivedTitle : currentTitle,
          deltaContent: deltaJson,
          plainText: plainText,
          at: nowSnapshot,
        );
      } catch (e) {
        nookLog(
          NookLogKey.editor,
          'Revision snapshot failed: $e',
          LogLevel.warning,
        );
      }

      final now = DateTime.now();
      final updatedNote = note.copyWith(
        title: derivedTitle.isNotEmpty ? derivedTitle : currentTitle,
        deltaContent: Value(deltaJson),
        plainText: Value(plainText),
        updatedAt: now,
      );

      _dirty = false;
      onSaved(derivedTitle, updatedNote);

      nookLog(
        NookLogKey.editor,
        'Note saved: ${note.id} (${plainText.length} chars)',
        LogLevel.info,
      );
    } finally {
      _saving = false;
      _notifyStatus();
      if (!isDisposed && _saveQueued) {
        _saveQueued = false;
        unawaited(
          save(
            editorState: editorState,
            note: note,
            db: db,
            currentTitle: currentTitle,
            isDisposed: isDisposed,
            onSaved: onSaved,
          ),
        );
      }
    }
  }

  /// Cleans up resources and performs a synchronous snapshot persist if dirty.
  void dispose({
    required EditorState? editorState,
    required Note? note,
    required AppDatabase? db,
    required String currentTitle,
    required bool dirty,
  }) {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;

    if (note != null && db != null && editorState != null && dirty) {
      final snapshot = snapshotContent(
        editorState: editorState,
        currentTitle: currentTitle,
        noteId: note.id,
        db: db,
      );
      unawaited(persistSnapshot(snapshot));
    }
  }
}
