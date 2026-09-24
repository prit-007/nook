import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/talker_provider.dart';
import '../database.dart';
import '../tables/attachments.dart';
import 'note_repository.dart';

/// Repository for Notebooks table operations.
class NotebookRepository {
  NotebookRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Creates a new notebook and returns the inserted row.
  Future<Notebook> createNotebook({
    required String name,
    required String colorSeed,
    String icon = 'notebook',
    int sortOrder = 0,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.notebooks).insert(
          NotebooksCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: colorSeed,
            icon: Value(icon),
            sortOrder: Value(sortOrder),
          ),
        );

    nookLog(NookLogKey.database, 'Notebook created: $id', LogLevel.debug);

    return (_db.select(_db.notebooks)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Creates a notebook with a specific ID (used during sync to preserve
  /// the remote notebook's identity so FK references resolve).
  Future<Notebook> createNotebookWithId(
    String id, {
    required String name,
    required String colorSeed,
    String icon = 'notebook',
    int sortOrder = 0,
  }) async {
    await _db.into(_db.notebooks).insert(
          NotebooksCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: colorSeed,
            icon: Value(icon),
            sortOrder: Value(sortOrder),
          ),
        );

    nookLog(NookLogKey.database, 'Notebook created (sync): $id',
        LogLevel.debug);

    return (_db.select(_db.notebooks)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Returns all non-deleted notebooks ordered by sortOrder ascending.
  Future<List<Notebook>> getAllNotebooks() async {
    return (_db.select(_db.notebooks)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Returns a notebook by ID, or null if not found.
  Future<Notebook?> getNotebookById(String id) async {
    final results =
        await (_db.select(_db.notebooks)..where((t) => t.id.equals(id))).get();
    return results.isEmpty ? null : results.first;
  }

  /// Returns multiple non-deleted notebooks by IDs in a single query.
  Future<List<Notebook>> getNotebooksByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    return (_db.select(_db.notebooks)
          ..where((t) => t.id.isIn(ids) & t.deleted.equals(false)))
        .get();
  }

  /// Updates a notebook's fields. Only non-null parameters are updated.
  Future<void> updateNotebook(
    String id, {
    String? name,
    String? colorSeed,
    String? icon,
    int? sortOrder,
  }) async {
    await (_db.update(_db.notebooks)..where((t) => t.id.equals(id))).write(
      NotebooksCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        colorSeed: colorSeed != null ? Value(colorSeed) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
      ),
    );
  }

  /// Deletes a notebook by ID and detaches all referencing notes.
  Future<void> deleteNotebook(String id) async {
    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((t) => t.notebookId.equals(id)))
          .write(const NotesCompanion(
        notebookId: Value(null),
      ));
      await (_db.delete(_db.notebooks)..where((t) => t.id.equals(id))).go();
    });
    nookLog(NookLogKey.database, 'Notebook deleted: $id', LogLevel.debug);
  }

  /// Soft-deletes a notebook. It will no longer appear in getAllNotebooks()
  /// but can be restored from the Bin.
  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.notebooks)..where((t) => t.id.equals(id))).write(
      NotebooksCompanion(
        deleted: const Value(true),
        deletedAt: Value(now),
      ),
    );
    nookLog(NookLogKey.database, 'Notebook soft-deleted: $id', LogLevel.debug);
  }

  /// Soft-deletes a notebook and all its notes. Notes are moved to trash.
  Future<void> softDeleteNotebookAndNotes(String id) async {
    final noteRepo = NoteRepository(_db);
    final notes = await (_db.select(_db.notes)
          ..where((t) => t.notebookId.equals(id)))
        .get();
    await _db.transaction(() async {
      for (final note in notes) {
        await noteRepo.softDelete(note.id);
      }
      await softDelete(id);
    });
    nookLog(
        NookLogKey.database,
        'Notebook soft-deleted with ${notes.length} notes: $id',
        LogLevel.debug);
  }

  /// Restores a soft-deleted notebook.
  Future<void> restore(String id) async {
    await (_db.update(_db.notebooks)..where((t) => t.id.equals(id))).write(
      const NotebooksCompanion(
        deleted: Value(false),
        deletedAt: Value(null),
      ),
    );
    nookLog(NookLogKey.database, 'Notebook restored: $id', LogLevel.debug);
  }

  /// Returns all soft-deleted notebooks ordered by most recently deleted first.
  Future<List<Notebook>> getDeletedNotebooks() async {
    return (_db.select(_db.notebooks)
          ..where((t) => t.deleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]))
        .get();
  }

  /// Deletes a notebook and soft-deletes all notes inside it.
  /// Notes are moved to trash so they can be restored later.
  Future<void> deleteNotebookAndNotes(String id) async {
    final noteRepo = NoteRepository(_db);
    final notes = await (_db.select(_db.notes)
          ..where((t) => t.notebookId.equals(id)))
        .get();
    await _db.transaction(() async {
      for (final note in notes) {
        await noteRepo.softDelete(note.id);
      }
      // Unlink notes from the notebook before deleting it (FK constraint).
      await (_db.update(_db.notes)..where((t) => t.notebookId.equals(id)))
          .write(const NotesCompanion(
        notebookId: Value(null),
      ));
      await (_db.delete(_db.notebooks)..where((t) => t.id.equals(id))).go();
    });
    nookLog(NookLogKey.database,
        'Notebook deleted with ${notes.length} notes: $id', LogLevel.debug);
  }

  /// Counts non-deleted notes in a notebook.
  Future<int> countNotesInNotebook(String notebookId) async {
    final count = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)
      ..where(_db.notes.notebookId.equals(notebookId) &
          _db.notes.deleted.equals(false))
      ..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Counts non-deleted notes for all notebooks in a single query.
  Future<Map<String, int>> countNotesForAllNotebooks() async {
    final count = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)
      ..where(
          _db.notes.deleted.equals(false) & _db.notes.notebookId.isNotNull())
      ..addColumns([_db.notes.notebookId, count])
      ..groupBy([_db.notes.notebookId]);
    final results = await query.get();
    final map = <String, int>{};
    for (final row in results) {
      final nbId = row.read(_db.notes.notebookId);
      if (nbId != null) {
        map[nbId] = row.read(count) ?? 0;
      }
    }
    return map;
  }

  /// Returns the most recently updated image attachment belonging to any
  /// non-deleted note in the notebook, or null when none exists.
  Future<Attachment?> getLatestImageForNotebook(String notebookId) async {
    final query = _db.select(_db.attachments).join([
      innerJoin(
        _db.notes,
        _db.notes.id.equalsExp(_db.attachments.noteId),
      ),
    ])
      ..where(_db.notes.notebookId.equals(notebookId) &
          _db.notes.deleted.equals(false) &
          _db.attachments.type.equalsValue(AttachmentType.image))
      ..orderBy([OrderingTerm.desc(_db.notes.updatedAt)]);
    final rows = await query.get();
    return rows.isEmpty ? null : rows.first.readTable(_db.attachments);
  }

  /// Permanently deletes a soft-deleted notebook (hard-deletes the row).
  Future<void> permanentlyDelete(String id) async {
    await (_db.delete(_db.notebooks)..where((t) => t.id.equals(id))).go();
    nookLog(NookLogKey.database, 'Notebook permanently deleted: $id',
        LogLevel.debug);
  }

  /// Permanently deletes all soft-deleted notebooks.
  Future<void> permanentlyDeleteAllDeleted() async {
    await (_db.delete(_db.notebooks)..where((t) => t.deleted.equals(true)))
        .go();
    nookLog(NookLogKey.database, 'All deleted notebooks permanently deleted',
        LogLevel.debug);
  }
}
