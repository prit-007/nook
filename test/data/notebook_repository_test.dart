import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;
  late NotebookRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotebookRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('NotebookRepository', () {
    test('createNotebook inserts and returns a notebook', () async {
      final nb = await repo.createNotebook(
        name: 'Work',
        colorSeed: '#FF5722',
      );

      expect(nb.name, 'Work');
      expect(nb.colorSeed, '#FF5722');
      expect(nb.id, isNotEmpty);
      expect(nb.icon, 'notebook');
      expect(nb.sortOrder, 0);
    });

    test('createNotebook with custom icon', () async {
      final nb = await repo.createNotebook(
        name: 'Personal',
        colorSeed: '#2196F3',
        icon: 'star',
      );

      expect(nb.icon, 'star');
    });

    test('getAllNotebooks returns all notebooks ordered by sortOrder',
        () async {
      await repo.createNotebook(name: 'B', colorSeed: '#111', sortOrder: 2);
      await repo.createNotebook(name: 'A', colorSeed: '#222', sortOrder: 1);
      await repo.createNotebook(name: 'C', colorSeed: '#333', sortOrder: 0);

      final all = await repo.getAllNotebooks();
      expect(all.length, 3);
      expect(all[0].name, 'C');
      expect(all[1].name, 'A');
      expect(all[2].name, 'B');
    });

    test('getNotebookById returns the correct notebook', () async {
      final created = await repo.createNotebook(
        name: 'Find Me',
        colorSeed: '#ABC',
      );

      final found = await repo.getNotebookById(created.id);
      expect(found, isNotNull);
      expect(found!.name, 'Find Me');
    });

    test('getNotebookById returns null for nonexistent id', () async {
      final found = await repo.getNotebookById('nonexistent');
      expect(found, isNull);
    });

    test('updateNotebook modifies name and colorSeed', () async {
      final nb = await repo.createNotebook(
        name: 'Old Name',
        colorSeed: '#000',
      );

      await repo.updateNotebook(
        nb.id,
        name: 'New Name',
        colorSeed: '#FFF',
      );

      final updated = await repo.getNotebookById(nb.id);
      expect(updated!.name, 'New Name');
      expect(updated.colorSeed, '#FFF');
    });

    test('deleteNotebook removes the notebook', () async {
      final nb = await repo.createNotebook(
        name: 'Delete Me',
        colorSeed: '#123',
      );

      await repo.deleteNotebook(nb.id);

      final found = await repo.getNotebookById(nb.id);
      expect(found, isNull);
    });

    test('updateNotebook sortOrder', () async {
      final nb = await repo.createNotebook(
        name: 'Reorderable',
        colorSeed: '#456',
      );

      await repo.updateNotebook(nb.id, sortOrder: 5);

      final updated = await repo.getNotebookById(nb.id);
      expect(updated!.sortOrder, 5);
    });

    test('countNotesInNotebook returns correct count', () async {
      final nb = await repo.createNotebook(
        name: 'With Notes',
        colorSeed: '#789',
      );

      // Insert notes into the notebook
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 1'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 2'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );
      // Note in a different notebook
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Other note'),
              type: NoteType.text,
              deviceOriginId: 'local',
            ),
          );

      final count = await repo.countNotesInNotebook(nb.id);
      expect(count, 2);
    });

    test('deleteNotebookAndNotes soft-deletes notes and removes notebook',
        () async {
      final nb = await repo.createNotebook(
        name: 'Delete With Notes',
        colorSeed: '#ABC',
      );

      // Insert notes into the notebook
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 1'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 2'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );

      await repo.deleteNotebookAndNotes(nb.id);

      // Notebook should be deleted
      final found = await repo.getNotebookById(nb.id);
      expect(found, isNull);

      // Notes should be soft-deleted (still in DB but marked deleted)
      final deletedNotes = await (db.select(db.notes)
            ..where((t) => t.deleted.equals(true)))
          .get();
      expect(deletedNotes, hasLength(2));
    });

    test('deleteNotebook only unlinks notes', () async {
      final nb = await repo.createNotebook(
        name: 'Unlink Only',
        colorSeed: '#DEF',
      );

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 1'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );

      await repo.deleteNotebook(nb.id);

      // Notebook should be deleted
      final found = await repo.getNotebookById(nb.id);
      expect(found, isNull);

      // Note should still be active (not soft-deleted)
      final activeNotes = await (db.select(db.notes)
            ..where((t) => t.deleted.equals(false)))
          .get();
      expect(activeNotes, hasLength(1));
      expect(activeNotes.first.notebookId, isNull);
    });
  });
}
