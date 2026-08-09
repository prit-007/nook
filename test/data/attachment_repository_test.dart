import 'package:drift/drift.dart';
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
}
