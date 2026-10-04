import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/repositories/trash_auto_purger.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  DateTime fixedNow() => DateTime(2026, 10, 4, 12);

  Future<void> softDeleteWithAge(
    String noteId,
    Duration age,
  ) async {
    final deletedAt = fixedNow().subtract(age);
    await (db.update(db.notes)..where((t) => t.id.equals(noteId))).write(
      NotesCompanion(
        deleted: const Value(true),
        deletedAt: Value(deletedAt),
      ),
    );
  }

  group('TrashAutoPurger', () {
    test('retention is 30 days', () {
      final purger = TrashAutoPurger(db, clock: fixedNow);
      expect(purger.retention, const Duration(days: 30));
      expect(kTrashRetentionDays, 30);
      expect(purger.cutoff, DateTime(2026, 9, 4, 12));
    });

    test('purges notes older than 30 days, keeps younger and live notes',
        () async {
      final noteRepo = NoteRepository(db);
      final old = await noteRepo.createNote(
        title: 'Old deleted',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final recent = await noteRepo.createNote(
        title: 'Recent deleted',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final live = await noteRepo.createNote(
        title: 'Live note',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      await softDeleteWithAge(old.id, const Duration(days: 31));
      await softDeleteWithAge(recent.id, const Duration(days: 10));

      final purger = TrashAutoPurger(db, clock: fixedNow);
      final result = await purger.purgeExpired();

      expect(result.notes, 1);
      expect(result.total, 1);

      final remainingDeleted = await noteRepo.getDeletedNotes();
      expect(remainingDeleted.map((n) => n.id), [recent.id]);

      final all = await noteRepo.getAllNotes();
      expect(all.map((n) => n.id), contains(live.id));
      expect(all.map((n) => n.id), isNot(contains(old.id)));
    });

    test('does not purge notes with deletedAt exactly at cutoff boundary',
        () async {
      final noteRepo = NoteRepository(db);
      final note = await noteRepo.createNote(
        title: 'Boundary',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      // deletedAt == cutoff → not strictly older → keep
      await softDeleteWithAge(note.id, const Duration(days: 30));

      final purger = TrashAutoPurger(db, clock: fixedNow);
      final result = await purger.purgeExpired();

      expect(result.notes, 0);
      expect((await noteRepo.getDeletedNotes()).length, 1);
    });

    test('never touches non-deleted rows even if old timestamps exist',
        () async {
      final noteRepo = NoteRepository(db);
      final note = await noteRepo.createNote(
        title: 'Still live',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      // Age updatedAt/deletedAt-style timestamps but keep deleted=false.
      await (db.update(db.notes)..where((t) => t.id.equals(note.id))).write(
        NotesCompanion(
          deletedAt: Value(fixedNow().subtract(const Duration(days: 90))),
        ),
      );

      final purger = TrashAutoPurger(db, clock: fixedNow);
      final result = await purger.purgeExpired();

      expect(result.isEmpty, isTrue);
      expect((await noteRepo.getAllNotes()).single.id, note.id);
    });

    test('purges expired notebooks and tags', () async {
      final notebookRepo = NotebookRepository(db);
      final tagRepo = TagRepository(db);

      final notebook = await notebookRepo.createNotebook(
        name: 'Old notebook',
        colorSeed: '#6750A4',
      );
      final tag = await tagRepo.createTag(
        name: 'old-tag',
        colorSeed: '#6750A4',
      );

      await (db.update(db.notebooks)..where((t) => t.id.equals(notebook.id)))
          .write(NotebooksCompanion(
        deleted: const Value(true),
        deletedAt: Value(fixedNow().subtract(const Duration(days: 40))),
      ));
      await (db.update(db.tags)..where((t) => t.id.equals(tag.id))).write(
        TagsCompanion(
          deleted: const Value(true),
          deletedAt: Value(fixedNow().subtract(const Duration(days: 40))),
        ),
      );

      final purger = TrashAutoPurger(db, clock: fixedNow);
      final result = await purger.purgeExpired();

      expect(result.notebooks, 1);
      expect(result.tags, 1);
      expect(await notebookRepo.getDeletedNotebooks(), isEmpty);
      expect(await tagRepo.getDeletedTags(), isEmpty);
    });

    test('empty bin → no-op result', () async {
      final purger = TrashAutoPurger(db, clock: fixedNow);
      final result = await purger.purgeExpired();
      expect(result.isEmpty, isTrue);
      expect(result.total, 0);
    });
  });
}
