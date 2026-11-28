import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
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

  group('Archive (schema v10)', () {
    test('archiveNote moves note out of getAllNotes and into getArchivedNotes',
        () async {
      final n1 = await repo.createNote(
        title: 'Active Note',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final n2 = await repo.createNote(
        title: 'Old Project',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );

      await repo.archiveNote(n2.id);

      final live = await repo.getAllNotes();
      expect(live.map((n) => n.id), [n1.id]);

      final archived = await repo.getArchivedNotes();
      expect(archived.map((n) => n.id), [n2.id]);
      expect(archived.first.archived, isTrue);
      expect(archived.first.deleted, isFalse);

      // Trash stays separate from Archive.
      expect(await repo.getDeletedNotes(), isEmpty);
    });

    test('unarchiveNote restores note back to getAllNotes', () async {
      final n1 = await repo.createNote(
        title: 'Archived Note',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await repo.archiveNote(n1.id);
      expect(await repo.getAllNotes(), isEmpty);

      await repo.unarchiveNote(n1.id);
      final live = await repo.getAllNotes();
      expect(live.map((n) => n.id), [n1.id]);
      expect(live.first.archived, isFalse);
      expect(await repo.getArchivedNotes(), isEmpty);
    });
  });
}
