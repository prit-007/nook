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
  static const int maxCollectionDepth = 4;

  /// Returns the depth of [notebookId] in the collection hierarchy (0 for root).
  Future<int> getNotebookDepth(String notebookId) async {
    int depth = 0;
    String? currentId = notebookId;
    final visited = <String>{};

    while (currentId != null) {
      if (visited.contains(currentId)) break;
      visited.add(currentId);

      final row = await (_db.select(_db.notebooks)
            ..where((t) => t.id.equals(currentId!)))
          .getSingleOrNull();
      if (row == null || row.parentId == null) {
        break;
      }
      depth++;
      currentId = row.parentId;
      if (depth >= 100) break;
    }
    return depth;
  }

  /// Calculates the maximum depth of descendants beneath [notebookId].
  Future<int> getSubtreeHeight(String notebookId) async {
    final children = await (_db.select(_db.notebooks)
          ..where(
              (t) => t.parentId.equals(notebookId) & t.deleted.equals(false)))
        .get();
    if (children.isEmpty) return 0;

    int maxHeight = 0;
    for (final child in children) {
      final h = await getSubtreeHeight(child.id);
      if (h + 1 > maxHeight) {
        maxHeight = h + 1;
      }
    }
    return maxHeight;
  }

  /// Returns `true` if setting [newParentId] as the parent of [id] would create
  /// a directed cycle (i.e. [newParentId] is [id] or a descendant of [id]).
  Future<bool> wouldCreateCycle(String id, String newParentId) async {
    if (id == newParentId) return true;
    final descendants = await getDescendantNotebookIds(id);
    return descendants.contains(newParentId);
  }

  /// Returns all descendant notebook IDs recursively.
  Future<List<String>> getDescendantNotebookIds(
    String notebookId, {
    bool includeDeleted = false,
  }) async {
    final results = <String>[];
    final queue = <String>[notebookId];
    final visited = <String>{notebookId};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final query = _db.select(_db.notebooks)
        ..where((t) {
          final cond = t.parentId.equals(current);
          return includeDeleted ? cond : cond & t.deleted.equals(false);
        });
      final children = await query.get();
      for (final child in children) {
        if (!visited.contains(child.id)) {
          visited.add(child.id);
          results.add(child.id);
          queue.add(child.id);
        }
      }
    }
    return results;
  }

  /// Reparents [id] to [newParentId], enforcing cycle prevention and maximum
  /// hierarchy depth of 4.
  Future<void> reparentNotebook(String id, String? newParentId) async {
    if (newParentId != null) {
      if (id == newParentId) {
        throw ArgumentError('Cannot reparent notebook into itself');
      }
      if (await wouldCreateCycle(id, newParentId)) {
        throw ArgumentError('Cannot reparent into own descendant');
      }
      final parentDepth = await getNotebookDepth(newParentId);
      final subtreeH = await getSubtreeHeight(id);
      if (parentDepth + 1 + subtreeH > maxCollectionDepth) {
        throw ArgumentError('Maximum depth of $maxCollectionDepth exceeded');
      }
    }

    await updateNotebook(id, parentId: Value(newParentId));
  }

  /// Creates a new notebook and returns the inserted row.
  Future<Notebook> createNotebook({
    required String name,
    required String colorSeed,
    String icon = 'notebook',
    int sortOrder = 0,
    String? parentId,
  }) async {
    if (parentId != null) {
      final parentDepth = await getNotebookDepth(parentId);
      if (parentDepth >= maxCollectionDepth) {
        throw ArgumentError('Maximum depth of $maxCollectionDepth exceeded');
      }
    }

    final id = _uuid.v4();
    await _db.into(_db.notebooks).insert(
          NotebooksCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: colorSeed,
            icon: Value(icon),
            sortOrder: Value(sortOrder),
            parentId: Value(parentId),
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
    String? parentId,
  }) async {
    if (parentId != null) {
      final parentDepth = await getNotebookDepth(parentId);
      if (parentDepth >= maxCollectionDepth) {
        throw ArgumentError('Maximum depth of $maxCollectionDepth exceeded');
      }
    }

    await _db.into(_db.notebooks).insert(
          NotebooksCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: colorSeed,
            icon: Value(icon),
            sortOrder: Value(sortOrder),
            parentId: Value(parentId),
          ),
        );

    nookLog(
        NookLogKey.database, 'Notebook created (sync): $id', LogLevel.debug);

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

  /// Returns all non-deleted root notebooks (with parentId == null).
  Future<List<Notebook>> getRootNotebooks() async {
    return (_db.select(_db.notebooks)
          ..where((t) => t.deleted.equals(false) & t.parentId.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Returns sub-notebooks belonging to a parent notebook.
  Future<List<Notebook>> getSubNotebooks(String parentId) async {
    return (_db.select(_db.notebooks)
          ..where((t) => t.deleted.equals(false) & t.parentId.equals(parentId))
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
    Value<String?> parentId = const Value.absent(),
  }) async {
    await (_db.update(_db.notebooks)..where((t) => t.id.equals(id))).write(
      NotebooksCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        colorSeed: colorSeed != null ? Value(colorSeed) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        parentId: parentId,
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

  /// Soft-deletes [id] and promotes its direct children to [id]'s parent.
  Future<void> softDeletePromotingChildren(String id) async {
    final nb = await getNotebookById(id);
    final parentOfDeleted = nb?.parentId;

    await _db.transaction(() async {
      await (_db.update(_db.notebooks)..where((t) => t.parentId.equals(id)))
          .write(NotebooksCompanion(parentId: Value(parentOfDeleted)));
      await softDelete(id);
    });
    nookLog(NookLogKey.database,
        'Notebook soft-deleted with children promoted: $id', LogLevel.debug);
  }

  /// Soft-deletes [id], its descendant notebooks, and all notes contained within.
  Future<void> softDeleteSubtree(String id) async {
    final descendantIds = await getDescendantNotebookIds(id);
    final allIds = [id, ...descendantIds];
    final now = DateTime.now();

    await _db.transaction(() async {
      await (_db.update(_db.notes)..where((t) => t.notebookId.isIn(allIds)))
          .write(NotesCompanion(
        deleted: const Value(true),
        deletedAt: Value(now),
      ));
      await (_db.update(_db.notebooks)..where((t) => t.id.isIn(allIds))).write(
        NotebooksCompanion(
          deleted: const Value(true),
          deletedAt: Value(now),
        ),
      );
    });
    nookLog(
        NookLogKey.database,
        'Subtree soft-deleted for notebook: $id (total ${allIds.length} collections)',
        LogLevel.debug);
  }

  /// Restores [id], its descendant notebooks, and their notes from trash.
  Future<void> restoreSubtree(String id) async {
    final descendantIds =
        await getDescendantNotebookIds(id, includeDeleted: true);
    final allIds = [id, ...descendantIds];

    await _db.transaction(() async {
      await (_db.update(_db.notebooks)..where((t) => t.id.isIn(allIds))).write(
        const NotebooksCompanion(
          deleted: Value(false),
          deletedAt: Value(null),
        ),
      );
      await (_db.update(_db.notes)..where((t) => t.notebookId.isIn(allIds)))
          .write(const NotesCompanion(
        deleted: Value(false),
        deletedAt: Value(null),
      ));
    });
    nookLog(
        NookLogKey.database,
        'Subtree restored for notebook: $id (total ${allIds.length} collections)',
        LogLevel.debug);
  }

  /// Counts non-deleted notes in [notebookId] plus all of its descendant notebooks.
  Future<int> countAggregateNotes(String notebookId) async {
    final descendantIds = await getDescendantNotebookIds(notebookId);
    final allIds = [notebookId, ...descendantIds];

    final count = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)
      ..where(
          _db.notes.notebookId.isIn(allIds) & _db.notes.deleted.equals(false))
      ..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Counts aggregate non-deleted notes for all non-deleted notebooks (including descendants).
  Future<Map<String, int>> countAggregateNotesForAllNotebooks() async {
    final allNotebooks = await getAllNotebooks();
    final directCounts = await countNotesForAllNotebooks();

    // Map parent -> children
    final childrenMap = <String, List<String>>{};
    for (final nb in allNotebooks) {
      if (nb.parentId != null) {
        childrenMap.putIfAbsent(nb.parentId!, () => []).add(nb.id);
      }
    }

    final memo = <String, int>{};
    int computeSubtree(String id) {
      if (memo.containsKey(id)) return memo[id]!;
      int sum = directCounts[id] ?? 0;
      final kids = childrenMap[id] ?? [];
      for (final kid in kids) {
        sum += computeSubtree(kid);
      }
      memo[id] = sum;
      return sum;
    }

    final resultMap = <String, int>{};
    for (final nb in allNotebooks) {
      resultMap[nb.id] = computeSubtree(nb.id);
    }
    return resultMap;
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
