import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

Future<void> insertDoodleLayer(AppDatabase db,
    {required String noteId, required String filePath}) async {
  await db.into(db.attachments).insert(
        AttachmentsCompanion.insert(
          noteId: noteId,
          type: AttachmentType.doodleLayer,
          filePath: filePath,
        ),
      );
}

void main() {
  late AppDatabase db;
  late AttachmentRepository repo;

  setUp(() async {
    db = createTestDb();
    repo = AttachmentRepository(db);

    // Create a test note for foreign key
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: const Value('note-1'),
            type: NoteType.text,
            title: const Value('Test'),
            deviceOriginId: 'device-1',
          ),
        );
  });

  tearDown(() async => db.close());

  group('addImage', () {
    test('returns a string id', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      expect(id, isA<String>());
      expect(id, isNotEmpty);
    });

    test('stores filePath', () async {
      final id = await repo.addImage(
        noteId: 'note-1',
        filePath: '/photos/sun.png',
      );
      final row = await repo.getById(id);
      expect(row!.filePath, '/photos/sun.png');
    });

    test('defaults thumbnailPath to null', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      final row = await repo.getById(id);
      expect(row!.thumbnailPath, equals(null));
    });

    test('defaults sortOrder to 0', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      final row = await repo.getById(id);
      expect(row!.sortOrder, 0);
    });

    test('accepts thumbnailPath', () async {
      final id = await repo.addImage(
        noteId: 'note-1',
        filePath: '/p/1.jpg',
        thumbnailPath: '/t/1_thumb.jpg',
      );
      final row = await repo.getById(id);
      expect(row!.thumbnailPath, '/t/1_thumb.jpg');
    });

    test('accepts sortOrder', () async {
      final id = await repo.addImage(
        noteId: 'note-1',
        filePath: '/p/1.jpg',
        sortOrder: 5,
      );
      final row = await repo.getById(id);
      expect(row!.sortOrder, 5);
    });
  });

  group('getImagesForNote', () {
    test('returns empty list when none exist', () async {
      final images = await repo.getImagesForNote('note-1');
      expect(images, isEmpty);
    });

    test('returns only images (not doodle layers)', () async {
      await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await insertDoodleLayer(db, noteId: 'note-1', filePath: '/d/1.draw');

      final images = await repo.getImagesForNote('note-1');
      expect(images, hasLength(1));
    });

    test('returns images ordered by sortOrder', () async {
      await repo.addImage(
        noteId: 'note-1',
        filePath: '/p/b.jpg',
        sortOrder: 2,
      );
      await repo.addImage(
        noteId: 'note-1',
        filePath: '/p/a.jpg',
        sortOrder: 1,
      );

      final images = await repo.getImagesForNote('note-1');
      expect(images.first.filePath, '/p/a.jpg');
      expect(images.last.filePath, '/p/b.jpg');
    });
  });

  group('getById', () {
    test('returns null for nonexistent id', () async {
      final result = await repo.getById('no-such-id');
      expect(result, equals(null));
    });
  });

  group('deleteImage', () {
    test('removes attachment by id', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.deleteImage(id);
      final result = await repo.getById(id);
      expect(result, equals(null));
    });
  });

  group('deleteAllForNote', () {
    test('removes all attachments for a note', () async {
      await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.addImage(noteId: 'note-1', filePath: '/p/2.jpg');
      await insertDoodleLayer(db, noteId: 'note-1', filePath: '/d/1.draw');

      await repo.deleteAllForNote('note-1');
      final remaining = await (db.select(db.attachments)
            ..where((a) => a.noteId.equals('note-1')))
          .get();
      expect(remaining, isEmpty);
    });
  });

  group('updateThumbnail', () {
    test('sets thumbnail path', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.updateThumbnail(id, '/t/new_thumb.jpg');
      final row = await repo.getById(id);
      expect(row!.thumbnailPath, '/t/new_thumb.jpg');
    });

    test('clears thumbnail path', () async {
      final id = await repo.addImage(
        noteId: 'note-1',
        filePath: '/p/1.jpg',
        thumbnailPath: '/t/old.jpg',
      );
      await repo.updateThumbnail(id, null);
      final row = await repo.getById(id);
      expect(row!.thumbnailPath, equals(null));
    });
  });

  group('reorderImages', () {
    test('updates sortOrder to match list order', () async {
      final id1 = await repo.addImage(
        noteId: 'note-1',
        filePath: '/p/1.jpg',
        sortOrder: 0,
      );
      final id2 = await repo.addImage(
        noteId: 'note-1',
        filePath: '/p/2.jpg',
        sortOrder: 1,
      );

      await repo.reorderImages([id2, id1]);

      final images = await repo.getImagesForNote('note-1');
      expect(images.first.id, id2);
      expect(images.last.id, id1);
      expect(images.first.sortOrder, 0);
      expect(images.last.sortOrder, 1);
    });
  });

  group('softDelete', () {
    test('sets deleted to true and deletedAt to non-null', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.softDelete(id);
      final row = await repo.getById(id);
      expect(row!.deleted, isTrue);
      expect(row.deletedAt, isNotNull);
    });

    test('excludes soft-deleted from getAllForNote', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.addImage(noteId: 'note-1', filePath: '/p/2.jpg');
      await repo.softDelete(id);

      final all = await repo.getAllForNote('note-1');
      expect(all, hasLength(1));
      expect(all.first.filePath, '/p/2.jpg');
    });

    test('excludes soft-deleted from getImagesForNote', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.addImage(noteId: 'note-1', filePath: '/p/2.jpg');
      await repo.softDelete(id);

      final images = await repo.getImagesForNote('note-1');
      expect(images, hasLength(1));
      expect(images.first.filePath, '/p/2.jpg');
    });

    test('excludes soft-deleted from getByFilePath', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.softDelete(id);

      final result = await repo.getByFilePath('/p/1.jpg');
      expect(result, isNull);
    });
  });

  group('restore', () {
    test('clears deleted and deletedAt', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.softDelete(id);
      await repo.restore(id);

      final row = await repo.getById(id);
      expect(row!.deleted, isFalse);
      expect(row.deletedAt, isNull);
    });

    test('makes attachment visible in queries again', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.softDelete(id);

      var all = await repo.getAllForNote('note-1');
      expect(all, isEmpty);

      await repo.restore(id);

      all = await repo.getAllForNote('note-1');
      expect(all, hasLength(1));
    });
  });

  group('getDeletedForNote', () {
    test('returns only soft-deleted attachments', () async {
      final id1 = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.addImage(noteId: 'note-1', filePath: '/p/2.jpg');
      await repo.softDelete(id1);

      final deleted = await repo.getDeletedForNote('note-1');
      expect(deleted, hasLength(1));
      expect(deleted.first.id, id1);
    });

    test('returns empty when no attachments are deleted', () async {
      await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      final deleted = await repo.getDeletedForNote('note-1');
      expect(deleted, isEmpty);
    });
  });

  group('softDeleteAllForNote', () {
    test('soft-deletes all attachments for a note', () async {
      await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.addImage(noteId: 'note-1', filePath: '/p/2.jpg');
      await insertDoodleLayer(db, noteId: 'note-1', filePath: '/d/1.draw');

      await repo.softDeleteAllForNote('note-1');

      final active = await repo.getAllForNote('note-1');
      expect(active, isEmpty);

      final deleted = await repo.getDeletedForNote('note-1');
      expect(deleted, hasLength(3));
    });
  });

  group('restoreAllForNote', () {
    test('restores all soft-deleted attachments for a note', () async {
      await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.addImage(noteId: 'note-1', filePath: '/p/2.jpg');
      await repo.softDeleteAllForNote('note-1');

      await repo.restoreAllForNote('note-1');

      final active = await repo.getAllForNote('note-1');
      expect(active, hasLength(2));
    });
  });

  group('permanentlyDelete', () {
    test('removes attachment from DB', () async {
      final id = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.permanentlyDelete(id);
      final result = await repo.getById(id);
      expect(result, isNull);
    });
  });

  group('getAllForNoteIncludingDeleted', () {
    test('returns all attachments including soft-deleted', () async {
      final id1 = await repo.addImage(noteId: 'note-1', filePath: '/p/1.jpg');
      await repo.addImage(noteId: 'note-1', filePath: '/p/2.jpg');
      await repo.softDelete(id1);

      final all = await repo.getAllForNoteIncludingDeleted('note-1');
      expect(all, hasLength(2));
    });
  });
}
