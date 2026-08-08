import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

/// Repository for ChecklistItems table operations.
class ChecklistItemRepository {
  ChecklistItemRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Adds a new checklist item to a note and returns the inserted row.
  Future<ChecklistItem> addItem({
    required String noteId,
    required String text,
    int? sortOrder,
  }) async {
    final id = _uuid.v4();
    final order = sortOrder ?? await _nextSortOrder(noteId);

    await _db.into(_db.checklistItems).insert(
          ChecklistItemsCompanion.insert(
            id: Value(id),
            noteId: noteId,
            itemText: text,
            sortOrder: Value(order),
          ),
        );

    return getItemById(id);
  }

  /// Returns all items for a note, ordered by sortOrder ascending.
  Future<List<ChecklistItem>> getItems(String noteId) async {
    return (_db.select(_db.checklistItems)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  /// Returns a single item by ID.
  Future<ChecklistItem> getItemById(String id) async {
    return (_db.select(_db.checklistItems)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Toggles the checked state of an item.
  Future<void> toggleChecked(String id) async {
    final item = await getItemById(id);
    await (_db.update(_db.checklistItems)..where((t) => t.id.equals(id))).write(
      ChecklistItemsCompanion(checked: Value(!item.checked)),
    );
  }

  /// Updates the text of an item.
  Future<void> updateText(String id, String text) async {
    await (_db.update(_db.checklistItems)..where((t) => t.id.equals(id))).write(
      ChecklistItemsCompanion(itemText: Value(text)),
    );
  }

  /// Deletes a single item.
  Future<void> deleteItem(String id) async {
    await (_db.delete(_db.checklistItems)..where((t) => t.id.equals(id))).go();
  }

  /// Deletes all items for a note.
  Future<void> deleteItemsByNote(String noteId) async {
    await (_db.delete(_db.checklistItems)
          ..where((t) => t.noteId.equals(noteId)))
        .go();
  }

  /// Reorders items by updating their sortOrder to match the given order.
  Future<void> reorderItems(String noteId, List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.checklistItems)
            ..where((t) => t.id.equals(orderedIds[i])))
          .write(
        ChecklistItemsCompanion(sortOrder: Value(i)),
      );
    }
  }

  Future<int> _nextSortOrder(String noteId) async {
    final items = await getItems(noteId);
    if (items.isEmpty) return 0;
    return items.last.sortOrder + 1;
  }
}
