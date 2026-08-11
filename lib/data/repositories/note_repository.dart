import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/notes.dart';

/// Repository for Notes table operations.
class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Creates a new note and returns the inserted row.
  Future<Note> createNote({
    required String title,
    required NoteType type,
    required String deviceOriginId,
    String? notebookId,
    String? colorSeed,
    String? deltaContent,
    String? plainText,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            type: type,
            title: Value(title),
            deviceOriginId: deviceOriginId,
            notebookId:
                notebookId != null ? Value(notebookId) : const Value.absent(),
            colorSeed: Value(colorSeed),
            deltaContent: Value(deltaContent),
            plainText: Value(plainText),
          ),
        );

    await _syncFts(id, title, plainText);

    return (_db.select(_db.notes)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Returns all non-deleted notes, ordered by pinned desc, then updatedAt desc.
  Future<List<Note>> getAllNotes() async {
    return (_db.select(_db.notes)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
  }

  /// Returns only locked notes.
  Future<List<Note>> getLockedNotes() async {
    return (_db.select(_db.notes)
          ..where((t) => t.deleted.equals(false) & t.locked.equals(true))
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
  }

  /// Returns a note by ID, or null if not found.
  Future<Note?> getNoteById(String id) async {
    final results =
        await (_db.select(_db.notes)..where((t) => t.id.equals(id))).get();
    return results.isEmpty ? null : results.first;
  }

  /// Updates a note's fields. Only non-null parameters are updated.
  Future<void> updateNote(
    String id, {
    String? title,
    String? colorSeed,
    bool? pinned,
    bool? locked,
    String? notebookId,
    int? syncVersion,
    DateTime? updatedAt,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        colorSeed: colorSeed != null ? Value(colorSeed) : const Value.absent(),
        pinned: pinned != null ? Value(pinned) : const Value.absent(),
        locked: locked != null ? Value(locked) : const Value.absent(),
        notebookId: Value(notebookId),
        syncVersion:
            syncVersion != null ? Value(syncVersion) : const Value.absent(),
        updatedAt: updatedAt != null ? Value(updatedAt) : Value(DateTime.now()),
      ),
    );
  }

  /// Updates the content (deltaContent + plainText) of a note.
  Future<void> updateContent(
    String id, {
    String? deltaContent,
    String? plainText,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deltaContent: Value(deltaContent),
        plainText: Value(plainText),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (plainText != null) {
      final note = await getNoteById(id);
      if (note != null) {
        await _syncFts(id, note.title, plainText);
      }
    }
  }

  /// Soft-deletes a note (sets deleted = true, deletedAt = now).
  Future<void> softDelete(String id) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deleted: const Value(true),
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Restores a soft-deleted note.
  Future<void> restore(String id) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deleted: const Value(false),
        deletedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Returns soft-deleted notes, ordered by deletedAt desc.
  Future<List<Note>> getDeletedNotes() async {
    return (_db.select(_db.notes)
          ..where((t) => t.deleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .get();
  }

  /// Permanently deletes a note from the database.
  Future<void> permanentlyDelete(String id) async {
    await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
  }

  /// Permanently deletes all soft-deleted notes in a single query.
  Future<void> permanentlyDeleteAllDeleted() async {
    await (_db.delete(_db.notes)..where((t) => t.deleted.equals(true))).go();
  }

  /// Replaces all tag assignments for a note with [tagIds].
  Future<void> updateNoteTags(String noteId, List<String> tagIds) async {
    await (_db.delete(_db.noteTags)..where((t) => t.noteId.equals(noteId)))
        .go();
    for (final tagId in tagIds) {
      await _db.into(_db.noteTags).insertOnConflictUpdate(
            NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
          );
    }
  }

  /// Returns only pinned, non-deleted notes.
  Future<List<Note>> getPinnedNotes() async {
    return (_db.select(_db.notes)
          ..where((t) => t.pinned.equals(true) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Returns non-deleted notes of a specific type.
  Future<List<Note>> getNotesByType(NoteType type) async {
    return (_db.select(_db.notes)
          ..where((t) => t.type.equalsValue(type) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// Syncs the FTS5 virtual table for a note.
  Future<void> _syncFts(String id, String title, String? plainText) async {
    await _db.customStatement(
      'DELETE FROM notes_fts WHERE id = ?',
      [id],
    );
    await _db.customStatement(
      'INSERT INTO notes_fts(id, title, plainText) VALUES(?, ?, ?)',
      [id, title, plainText ?? ''],
    );
  }
}
