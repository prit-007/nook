import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('NoteRepository', () {
    test('createNote inserts a note and returns it', () async {
      final note = await repo.createNote(
        title: 'Groceries',
        type: NoteType.text,
        deviceOriginId: 'device-1',
      );

      expect(note.title, 'Groceries');
      expect(note.type, NoteType.text);
      expect(note.deviceOriginId, 'device-1');
      expect(note.id, isNotEmpty);
      expect(note.pinned, false);
      expect(note.locked, false);
      expect(note.deleted, false);
      expect(note.syncVersion, 0);
    });

    test('createChecklistNote inserts with checklist type', () async {
      final note = await repo.createNote(
        title: 'Tasks',
        type: NoteType.checklist,
        deviceOriginId: 'device-1',
      );

      expect(note.type, NoteType.checklist);
    });

    test('createDoodleNote inserts with doodle type', () async {
      final note = await repo.createNote(
        title: 'Sketch',
        type: NoteType.doodle,
        deviceOriginId: 'device-1',
      );

      expect(note.type, NoteType.doodle);
    });

    test('getAllNotes returns all non-deleted notes', () async {
      await repo.createNote(
        title: 'Note 1',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await repo.createNote(
        title: 'Note 2',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      final notes = await repo.getAllNotes();
      expect(notes.length, 2);
    });

    test('getAllNotes excludes soft-deleted notes', () async {
      final note = await repo.createNote(
        title: 'Deleted Note',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await repo.softDelete(note.id);

      final notes = await repo.getAllNotes();
      expect(notes.length, 0);
    });

    test('getNoteById returns the correct note', () async {
      final created = await repo.createNote(
        title: 'Find Me',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      final found = await repo.getNoteById(created.id);
      expect(found, isNotNull);
      expect(found!.title, 'Find Me');
    });

    test('getNoteById returns null for nonexistent id', () async {
      final found = await repo.getNoteById('nonexistent');
      expect(found, isNull);
    });

    test('updateNote modifies title', () async {
      final note = await repo.createNote(
        title: 'Old Title',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      await repo.updateNote(note.id, title: 'New Title');

      final updated = await repo.getNoteById(note.id);
      expect(updated!.title, 'New Title');
    });

    test('updateNote modifies pinned', () async {
      final note = await repo.createNote(
        title: 'Pinnable',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      await repo.updateNote(note.id, pinned: true);

      final updated = await repo.getNoteById(note.id);
      expect(updated!.pinned, true);
    });

    test('softDelete marks note as deleted', () async {
      final note = await repo.createNote(
        title: 'To Delete',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      await repo.softDelete(note.id);

      final deleted = await repo.getNoteById(note.id);
      expect(deleted, isNotNull);
      expect(deleted!.deleted, true);
      expect(deleted.deletedAt, isNotNull);
    });

    test('restoreNote un-deletes a soft-deleted note', () async {
      final note = await repo.createNote(
        title: 'To Restore',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await repo.softDelete(note.id);

      await repo.restore(note.id);

      final restored = await repo.getNoteById(note.id);
      expect(restored!.deleted, false);
      expect(restored.deletedAt, isNull);
    });

    test('permanentlyDelete removes note from DB', () async {
      final note = await repo.createNote(
        title: 'Gone Forever',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      await repo.permanentlyDelete(note.id);

      final found = await repo.getNoteById(note.id);
      expect(found, isNull);
    });

    test('getPinnedNotes returns only pinned notes', () async {
      final note1 = await repo.createNote(
        title: 'Pinned',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await repo.createNote(
        title: 'Not Pinned',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await repo.updateNote(note1.id, pinned: true);

      final pinned = await repo.getPinnedNotes();
      expect(pinned.length, 1);
      expect(pinned.first.title, 'Pinned');
    });

    test('getNotesByType filters by note type', () async {
      await repo.createNote(
        title: 'Text',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await repo.createNote(
        title: 'Checklist',
        type: NoteType.checklist,
        deviceOriginId: 'd1',
      );
      await repo.createNote(
        title: 'Doodle',
        type: NoteType.doodle,
        deviceOriginId: 'd1',
      );

      final checklists = await repo.getNotesByType(NoteType.checklist);
      expect(checklists.length, 1);
      expect(checklists.first.title, 'Checklist');
    });

    test('updateContent saves deltaContent and plainText', () async {
      final note = await repo.createNote(
        title: 'Content Test',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      await repo.updateContent(
        note.id,
        deltaContent: '{"document":{"type":"page","children":[]}}',
        plainText: 'Hello world',
      );

      final updated = await repo.getNoteById(note.id);
      expect(
          updated!.deltaContent, '{"document":{"type":"page","children":[]}}');
      expect(updated.plainText, 'Hello world');
    });

    test('softDelete cascades to soft-delete attachments', () async {
      final note = await repo.createNote(
        title: 'With Attachments',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final attRepo = AttachmentRepository(db);
      await attRepo.addImage(noteId: note.id, filePath: '/p/1.jpg');
      await attRepo.addImage(noteId: note.id, filePath: '/p/2.jpg');

      await repo.softDelete(note.id);

      // Attachments should be soft-deleted
      final active = await attRepo.getAllForNote(note.id);
      expect(active, isEmpty);

      final deleted = await attRepo.getDeletedForNote(note.id);
      expect(deleted, hasLength(2));
    });

    test('restore cascades to restore attachments', () async {
      final note = await repo.createNote(
        title: 'With Attachments',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final attRepo = AttachmentRepository(db);
      await attRepo.addImage(noteId: note.id, filePath: '/p/1.jpg');
      await attRepo.addImage(noteId: note.id, filePath: '/p/2.jpg');

      await repo.softDelete(note.id);
      await repo.restore(note.id);

      // Attachments should be restored
      final active = await attRepo.getAllForNote(note.id);
      expect(active, hasLength(2));
    });

    test('permanentlyDelete removes attachment rows', () async {
      final note = await repo.createNote(
        title: 'With Attachments',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final attRepo = AttachmentRepository(db);
      await attRepo.addImage(noteId: note.id, filePath: '/p/1.jpg');
      await attRepo.addImage(noteId: note.id, filePath: '/p/2.jpg');

      await repo.permanentlyDelete(note.id);

      // Attachment rows should be gone
      final all = await attRepo.getAllForNoteIncludingDeleted(note.id);
      expect(all, isEmpty);
    });
  });
}
