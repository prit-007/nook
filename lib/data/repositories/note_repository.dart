import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/talker_provider.dart';
import '../database.dart';
import '../tables/notes.dart';
import 'attachment_repository.dart';

/// Repository for Notes table operations.
class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Creates a new note and returns the inserted row.
  ///
  /// If [id] is provided (e.g. from a remote device), it is used instead of
  /// generating a new UUID. This preserves cross-device identity during sync.
  Future<Note> createNote({
    String? id,
    required String title,
    required NoteType type,
    required String deviceOriginId,
    String? notebookId,
    String? colorSeed,
    String? deltaContent,
    String? plainText,
    int? syncVersion,
  }) async {
    final noteId = id ?? _uuid.v4();
    try {
      await _db.into(_db.notes).insert(
            NotesCompanion.insert(
              id: Value(noteId),
              type: type,
              title: Value(title),
              deviceOriginId: deviceOriginId,
              notebookId:
                  notebookId != null ? Value(notebookId) : const Value.absent(),
              colorSeed: Value(colorSeed),
              deltaContent: Value(deltaContent),
              plainText: Value(plainText),
              syncVersion: syncVersion != null
                  ? Value(syncVersion)
                  : const Value.absent(),
            ),
          );

      await _syncFts(noteId, title, plainText);
    } catch (e) {
      nookLog(NookLogKey.database, 'Note create failed: $e', LogLevel.error);
      rethrow;
    }

    nookLog(NookLogKey.database, 'Note created: $noteId', LogLevel.debug);

    return (_db.select(_db.notes)..where((t) => t.id.equals(noteId)))
        .getSingle();
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
  /// [updatedAt] defaults to now for local edits. Sync callers pass explicit value.
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
        notebookId:
            notebookId != null ? Value(notebookId) : const Value.absent(),
        syncVersion:
            syncVersion != null ? Value(syncVersion) : const Value.absent(),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );
  }

  /// Increments only the `syncVersion` column, leaving `updatedAt` untouched.
  /// Used after a successful sync send so the timestamp does not drift and
  /// cause spurious conflicts on the next merge.
  Future<void> bumpSyncVersion(String id) async {
    await _db.customStatement(
      'UPDATE notes SET sync_version = sync_version + 1 WHERE id = ?',
      [id],
    );
  }

  /// Updates the content (deltaContent + plainText) of a note.
  /// If [updatedAt] is not provided, defaults to now (for local edits).
  /// Sync callers should pass the remote timestamp explicitly.
  Future<void> updateContent(
    String id, {
    String? deltaContent,
    String? plainText,
    DateTime? updatedAt,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deltaContent: Value(deltaContent),
        plainText: Value(plainText),
        updatedAt: Value(updatedAt ?? DateTime.now()),
      ),
    );

    if (plainText != null) {
      final note = await getNoteById(id);
      if (note != null) {
        await _syncFts(id, note.title, plainText);
      }
    }
    nookLog(NookLogKey.database, 'Note content saved: $id', LogLevel.debug);
  }

  /// Soft-deletes a note and all its attachments.
  Future<void> softDelete(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
        NotesCompanion(
          deleted: const Value(true),
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await AttachmentRepository(_db).softDeleteAllForNote(id);
    });
    nookLog(NookLogKey.database, 'Note soft-deleted: $id', LogLevel.debug);
  }

  /// Restores a soft-deleted note and all its attachments.
  Future<void> restore(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
        NotesCompanion(
          deleted: const Value(false),
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await AttachmentRepository(_db).restoreAllForNote(id);
    });
    nookLog(NookLogKey.database, 'Note restored: $id', LogLevel.debug);
  }

  /// Returns soft-deleted notes, ordered by deletedAt desc.
  Future<List<Note>> getDeletedNotes() async {
    return (_db.select(_db.notes)
          ..where((t) => t.deleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .get();
  }

  /// Permanently deletes a note and all associated data including on-disk files.
  Future<void> permanentlyDelete(String id) async {
    try {
      final attachmentRepo = AttachmentRepository(_db);
      // Delete on-disk files for all attachments first.
      final attachments =
          await attachmentRepo.getAllForNoteIncludingDeleted(id);
      for (final att in attachments) {
        await attachmentRepo.deleteFilesForAttachment(att);
      }

      await _db.transaction(() async {
        await (_db.delete(_db.noteTags)..where((t) => t.noteId.equals(id)))
            .go();
        await (_db.delete(_db.checklistItems)
              ..where((t) => t.noteId.equals(id)))
            .go();
        await (_db.delete(_db.attachments)..where((a) => a.noteId.equals(id)))
            .go();
        await _db.customStatement(
          'DELETE FROM notes_fts WHERE id = ?',
          [id],
        );
        await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
      });
    } catch (e) {
      nookLog(NookLogKey.database, 'Note permanent delete failed: $e',
          LogLevel.error);
      rethrow;
    }
    nookLog(
        NookLogKey.database, 'Note permanently deleted: $id', LogLevel.debug);
  }

  /// Permanently deletes all soft-deleted notes and their associated data,
  /// including on-disk attachment files.
  Future<void> permanentlyDeleteAllDeleted() async {
    final deleted = await getDeletedNotes();
    if (deleted.isEmpty) return;

    final attachmentRepo = AttachmentRepository(_db);
    // Delete on-disk files for all attachments of deleted notes.
    for (final note in deleted) {
      final attachments =
          await attachmentRepo.getAllForNoteIncludingDeleted(note.id);
      for (final att in attachments) {
        await attachmentRepo.deleteFilesForAttachment(att);
      }
    }

    await _db.transaction(() async {
      for (final note in deleted) {
        await (_db.delete(_db.noteTags)..where((t) => t.noteId.equals(note.id)))
            .go();
        await (_db.delete(_db.checklistItems)
              ..where((t) => t.noteId.equals(note.id)))
            .go();
        await (_db.delete(_db.attachments)
              ..where((a) => a.noteId.equals(note.id)))
            .go();
        await _db.customStatement(
          'DELETE FROM notes_fts WHERE id = ?',
          [note.id],
        );
      }
      await (_db.delete(_db.notes)..where((t) => t.deleted.equals(true))).go();
    });
  }

  /// Replaces all tag assignments for a note with [tagIds] atomically.
  Future<void> updateNoteTags(String noteId, List<String> tagIds) async {
    await _db.transaction(() async {
      await (_db.delete(_db.noteTags)..where((t) => t.noteId.equals(noteId)))
          .go();
      for (final tagId in tagIds) {
        await _db.into(_db.noteTags).insertOnConflictUpdate(
              NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
            );
      }
    });
    nookLog(
      NookLogKey.database,
      'Note tags updated: $noteId (${tagIds.length})',
      LogLevel.debug,
    );
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

  /// Syncs the FTS5 virtual table for a note atomically.
  Future<void> _syncFts(String id, String title, String? plainText) async {
    await _db.customStatement(
      'INSERT OR REPLACE INTO notes_fts(id, title, plainText) VALUES(?, ?, ?)',
      [id, title, plainText ?? ''],
    );
  }
}
