import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/attachments.dart';

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

    return (_db.select(_db.notebooks)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Returns all notebooks ordered by sortOrder ascending.
  Future<List<Notebook>> getAllNotebooks() async {
    return (_db.select(_db.notebooks)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Returns a notebook by ID, or null if not found.
  Future<Notebook?> getNotebookById(String id) async {
    final results =
        await (_db.select(_db.notebooks)..where((t) => t.id.equals(id))).get();
    return results.isEmpty ? null : results.first;
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

  /// Deletes a notebook by ID.
  Future<void> deleteNotebook(String id) async {
    await (_db.delete(_db.notebooks)..where((t) => t.id.equals(id))).go();
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
}
