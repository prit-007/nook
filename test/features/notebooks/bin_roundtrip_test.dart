import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late NotebookRepository notebookRepo;
  late NoteRepository noteRepo;
  late AttachmentRepository attachmentRepo;
  late TagRepository tagRepo;

  setUp(() {
    db = createTestDb();
    notebookRepo = NotebookRepository(db);
    noteRepo = NoteRepository(db);
    attachmentRepo = AttachmentRepository(db);
    tagRepo = TagRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('"Notebook only" round-trip', () {
    testWidgets('restoring notebook preserves note links', (tester) async {
      // Setup: notebook with 2 notes.
      final nb = await notebookRepo.createNotebook(
          name: 'My Notebook', colorSeed: '#FF0000');
      final note1 = await noteRepo.createNote(
        title: 'Note 1',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );
      final note2 = await noteRepo.createNote(
        title: 'Note 2',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );

      // Soft-delete notebook only (notes stay active).
      await notebookRepo.softDelete(nb.id);

      // Verify notebook is soft-deleted.
      final deleted = await notebookRepo.getDeletedNotebooks();
      expect(deleted, hasLength(1));
      expect(deleted.first.id, nb.id);

      // Verify notes are still active.
      final activeNotes = await noteRepo.getAllNotes();
      expect(activeNotes, hasLength(2));

      // Verify notes still link to the (deleted) notebook.
      final note1Refresh = await noteRepo.getNoteById(note1.id);
      final note2Refresh = await noteRepo.getNoteById(note2.id);
      expect(note1Refresh!.notebookId, nb.id);
      expect(note2Refresh!.notebookId, nb.id);

      // Restore notebook.
      await notebookRepo.restore(nb.id);

      // Verify notebook is active again.
      final activeNbs = await notebookRepo.getAllNotebooks();
      expect(activeNbs, hasLength(1));
      expect(activeNbs.first.id, nb.id);

      // Verify notes are still linked to the restored notebook.
      final note1After = await noteRepo.getNoteById(note1.id);
      final note2After = await noteRepo.getNoteById(note2.id);
      expect(note1After!.notebookId, nb.id);
      expect(note2After!.notebookId, nb.id);
    });

    testWidgets('restoring notebook preserves note attachments',
        (tester) async {
      final nb = await notebookRepo.createNotebook(
          name: 'With Attachments', colorSeed: '#FF0000');
      final note = await noteRepo.createNote(
        title: 'Note with Image',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );

      // Insert an attachment on the note.
      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-1'),
              noteId: note.id,
              type: AttachmentType.image,
              filePath: '/tmp/img.jpg',
            ),
          );

      // Soft-delete notebook only.
      await notebookRepo.softDelete(nb.id);

      // Verify attachment is still active (not soft-deleted).
      final atts = await attachmentRepo.getAllForNote(note.id);
      expect(atts, hasLength(1));
      expect(atts.first.id, 'att-1');

      // Restore notebook.
      await notebookRepo.restore(nb.id);

      // Verify attachment is still there and active.
      final attsAfter = await attachmentRepo.getAllForNote(note.id);
      expect(attsAfter, hasLength(1));
      expect(attsAfter.first.filePath, '/tmp/img.jpg');
    });

    testWidgets('restoring notebook preserves tag associations',
        (tester) async {
      final nb = await notebookRepo.createNotebook(
          name: 'Tagged NB', colorSeed: '#FF0000');
      final note = await noteRepo.createNote(
        title: 'Tagged Note',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );
      final tag = await tagRepo.createTag(
        name: 'important',
        colorSeed: '#2196F3',
      );
      await tagRepo.assignTagToNote(note.id, tag.id);

      // Soft-delete notebook only.
      await notebookRepo.softDelete(nb.id);

      // Verify tag association still exists.
      final tagsForNote = await tagRepo.getTagsForNote(note.id);
      expect(tagsForNote, hasLength(1));
      expect(tagsForNote.first.id, tag.id);

      // Restore notebook.
      await notebookRepo.restore(nb.id);

      // Verify tag association is preserved.
      final tagsAfter = await tagRepo.getTagsForNote(note.id);
      expect(tagsAfter, hasLength(1));
      expect(tagsAfter.first.id, tag.id);
    });
  });

  group('"Notes too" round-trip', () {
    testWidgets('restoring notes preserves notebook link', (tester) async {
      final nb = await notebookRepo.createNotebook(
          name: 'Full Bin', colorSeed: '#FF0000');
      final note = await noteRepo.createNote(
        title: 'Doomed Note',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );

      // Soft-delete notebook AND notes.
      await notebookRepo.softDeleteNotebookAndNotes(nb.id);

      // Verify both are soft-deleted.
      final deletedNbs = await notebookRepo.getDeletedNotebooks();
      expect(deletedNbs, hasLength(1));
      final deletedNotes = await noteRepo.getDeletedNotes();
      expect(deletedNotes, hasLength(1));
      expect(deletedNotes.first.id, note.id);

      // Verify the deleted note still holds its notebookId.
      expect(deletedNotes.first.notebookId, nb.id);

      // Restore notebook first.
      await notebookRepo.restore(nb.id);

      // Restore note.
      await noteRepo.restore(note.id);

      // Verify notebook is active.
      final activeNbs = await notebookRepo.getAllNotebooks();
      expect(activeNbs, hasLength(1));

      // Verify note is active and still linked to the notebook.
      final restoredNote = await noteRepo.getNoteById(note.id);
      expect(restoredNote, isNotNull);
      expect(restoredNote!.notebookId, nb.id);
    });

    testWidgets('restoring notes preserves attachments and doodles',
        (tester) async {
      final nb = await notebookRepo.createNotebook(
          name: 'Media NB', colorSeed: '#FF0000');
      final note = await noteRepo.createNote(
        title: 'Media Note',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );

      // Insert an image attachment and a doodle attachment.
      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-img'),
              noteId: note.id,
              type: AttachmentType.image,
              filePath: '/tmp/photo.jpg',
            ),
          );
      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-doodle'),
              noteId: note.id,
              type: AttachmentType.doodleLayer,
              filePath: '/tmp/doodle.json',
            ),
          );

      // Soft-delete notebook AND notes.
      await notebookRepo.softDeleteNotebookAndNotes(nb.id);

      // Verify note's attachments are also soft-deleted.
      final deletedAtts = await (db.select(db.attachments)
            ..where((a) => a.deleted.equals(true)))
          .get();
      expect(deletedAtts, hasLength(2));
      final deletedIds = deletedAtts.map((a) => a.id).toSet();
      expect(deletedIds, containsAll(['att-img', 'att-doodle']));

      // Restore notebook.
      await notebookRepo.restore(nb.id);

      // Restore note (and its attachments via NoteRepository.restore).
      await noteRepo.restore(note.id);

      // Verify attachments are restored.
      final imgAtt = await attachmentRepo.getById('att-img');
      expect(imgAtt, isNotNull);
      expect(imgAtt!.deleted, false);

      final doodleAtt = await attachmentRepo.getById('att-doodle');
      expect(doodleAtt, isNotNull);
      expect(doodleAtt!.deleted, false);

      // Verify attachment types are preserved.
      expect(imgAtt.type, AttachmentType.image);
      expect(doodleAtt.type, AttachmentType.doodleLayer);
    });

    testWidgets('restoring notes preserves tag associations', (tester) async {
      final nb = await notebookRepo.createNotebook(
          name: 'Tagged Full', colorSeed: '#FF0000');
      final note = await noteRepo.createNote(
        title: 'Tagged Note',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );
      final tag = await tagRepo.createTag(
        name: 'urgent',
        colorSeed: '#FF5722',
      );
      await tagRepo.assignTagToNote(note.id, tag.id);

      // Soft-delete notebook AND notes.
      await notebookRepo.softDeleteNotebookAndNotes(nb.id);

      // Verify tag associations still exist (noteTags is not soft-deleted,
      // only the note row is).
      final tagsForNote = await tagRepo.getTagsForNote(note.id);
      expect(tagsForNote, hasLength(1));
      expect(tagsForNote.first.id, tag.id);

      // Restore notebook.
      await notebookRepo.restore(nb.id);

      // Restore note.
      await noteRepo.restore(note.id);

      // Verify tag association is preserved.
      final tagsAfter = await tagRepo.getTagsForNote(note.id);
      expect(tagsAfter, hasLength(1));
      expect(tagsAfter.first.id, tag.id);
    });

    testWidgets('restoring notes preserves checklist items', (tester) async {
      final nb = await notebookRepo.createNotebook(
          name: 'Checklist NB', colorSeed: '#FF0000');
      final note = await noteRepo.createNote(
        title: 'Checklist Note',
        type: NoteType.checklist,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );

      // Insert a checklist item.
      await db.into(db.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              noteId: note.id,
              itemText: 'Buy milk',
              checked: const Value(false),
              sortOrder: const Value(0),
            ),
          );

      // Soft-delete notebook AND notes.
      await notebookRepo.softDeleteNotebookAndNotes(nb.id);

      // Verify checklist items still exist.
      final items = await (db.select(db.checklistItems)
            ..where((c) => c.noteId.equals(note.id)))
          .get();
      expect(items, hasLength(1));
      expect(items.first.itemText, 'Buy milk');
      expect(items.first.checked, false);

      // Restore notebook.
      await notebookRepo.restore(nb.id);

      // Restore note.
      await noteRepo.restore(note.id);

      // Verify checklist item is preserved.
      final itemsAfter = await (db.select(db.checklistItems)
            ..where((c) => c.noteId.equals(note.id)))
          .get();
      expect(itemsAfter, hasLength(1));
      expect(itemsAfter.first.itemText, 'Buy milk');
      expect(itemsAfter.first.checked, false);
    });

    testWidgets('multiple notes in notebook all restored correctly',
        (tester) async {
      final nb = await notebookRepo.createNotebook(
          name: 'Multi Note', colorSeed: '#FF0000');
      final note1 = await noteRepo.createNote(
        title: 'First',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );
      final note2 = await noteRepo.createNote(
        title: 'Second',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );
      final note3 = await noteRepo.createNote(
        title: 'Third',
        type: NoteType.text,
        deviceOriginId: 'device-1',
        notebookId: nb.id,
      );

      // Add attachments to each note.
      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-1'),
              noteId: note1.id,
              type: AttachmentType.image,
              filePath: '/tmp/att1.jpg',
            ),
          );
      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-2'),
              noteId: note2.id,
              type: AttachmentType.image,
              filePath: '/tmp/att2.jpg',
            ),
          );
      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-3'),
              noteId: note3.id,
              type: AttachmentType.doodleLayer,
              filePath: '/tmp/att3.json',
            ),
          );

      // Soft-delete notebook AND all notes.
      await notebookRepo.softDeleteNotebookAndNotes(nb.id);

      // Restore notebook.
      await notebookRepo.restore(nb.id);

      // Restore all 3 notes.
      await noteRepo.restore(note1.id);
      await noteRepo.restore(note2.id);
      await noteRepo.restore(note3.id);

      // Verify all notes are active and linked.
      final activeNotes = await noteRepo.getAllNotes();
      expect(activeNotes, hasLength(3));
      for (final n in activeNotes) {
        expect(n.notebookId, nb.id);
      }

      // Verify all attachments are restored.
      final att1 = await attachmentRepo.getById('att-1');
      expect(att1, isNotNull);
      expect(att1!.deleted, false);

      final att2 = await attachmentRepo.getById('att-2');
      expect(att2, isNotNull);
      expect(att2!.deleted, false);

      final att3 = await attachmentRepo.getById('att-3');
      expect(att3, isNotNull);
      expect(att3!.deleted, false);
      expect(att3.type, AttachmentType.doodleLayer);
    });
  });
}
