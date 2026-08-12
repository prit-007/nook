import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/tables/notes.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late ChecklistItemRepository repo;
  late String noteId;

  setUp(() async {
    db = createTestDb();
    repo = ChecklistItemRepository(db);

    // Create a checklist note to reference
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: const Value('note-1'),
            type: NoteType.checklist,
            title: const Value('Test Checklist'),
            deviceOriginId: 'device-1',
          ),
        );
    noteId = 'note-1';
  });

  tearDown(() async {
    await db.close();
  });

  test('addItem inserts and returns a checklist item', () async {
    final item = await repo.addItem(noteId: noteId, text: 'Milk');
    expect(item.id, isNotEmpty);
    expect(item.noteId, equals(noteId));
    expect(item.itemText, equals('Milk'));
    expect(item.checked, isFalse);
    expect(item.sortOrder, equals(0));
  });

  test('getItems returns items for a note ordered by sortOrder', () async {
    await repo.addItem(noteId: noteId, text: 'First');
    await repo.addItem(noteId: noteId, text: 'Second');
    await repo.addItem(noteId: noteId, text: 'Third');

    final items = await repo.getItems(noteId);
    expect(items.length, equals(3));
    expect(items[0].itemText, equals('First'));
    expect(items[1].itemText, equals('Second'));
    expect(items[2].itemText, equals('Third'));
  });

  test('getItems returns empty list for note with no items', () async {
    final items = await repo.getItems(noteId);
    expect(items, isEmpty);
  });

  test('toggleChecked flips the checked state', () async {
    final item = await repo.addItem(noteId: noteId, text: 'Task');
    expect(item.checked, isFalse);

    await repo.toggleChecked(item.id);
    final updated = await repo.getItemById(item.id);
    expect(updated, isNotNull);
    expect(updated!.checked, isTrue);

    await repo.toggleChecked(item.id);
    final toggledBack = await repo.getItemById(item.id);
    expect(toggledBack, isNotNull);
    expect(toggledBack!.checked, isFalse);
  });

  test('updateText changes the item text', () async {
    final item = await repo.addItem(noteId: noteId, text: 'Old text');
    await repo.updateText(item.id, 'New text');

    final updated = await repo.getItemById(item.id);
    expect(updated, isNotNull);
    expect(updated!.itemText, equals('New text'));
  });

  test('deleteItem removes the item', () async {
    final item = await repo.addItem(noteId: noteId, text: 'Delete me');
    expect((await repo.getItems(noteId)).length, equals(1));

    await repo.deleteItem(item.id);
    expect((await repo.getItems(noteId)), isEmpty);
  });

  test('reorderItems updates sort orders', () async {
    final a = await repo.addItem(noteId: noteId, text: 'A');
    final b = await repo.addItem(noteId: noteId, text: 'B');
    final c = await repo.addItem(noteId: noteId, text: 'C');

    // Move C to first position
    await repo.reorderItems(noteId, [c.id, a.id, b.id]);

    final items = await repo.getItems(noteId);
    expect(items[0].itemText, equals('C'));
    expect(items[1].itemText, equals('A'));
    expect(items[2].itemText, equals('B'));
    expect(items[0].sortOrder, equals(0));
    expect(items[1].sortOrder, equals(1));
    expect(items[2].sortOrder, equals(2));
  });

  test('addItem assigns sequential sort orders', () async {
    final a = await repo.addItem(noteId: noteId, text: 'A');
    final b = await repo.addItem(noteId: noteId, text: 'B');
    expect(a.sortOrder, equals(0));
    expect(b.sortOrder, equals(1));
  });

  test('deleteItemsByNote removes all items for a note', () async {
    await repo.addItem(noteId: noteId, text: 'A');
    await repo.addItem(noteId: noteId, text: 'B');

    await repo.deleteItemsByNote(noteId);
    expect((await repo.getItems(noteId)), isEmpty);
  });
}
