import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/trash_auto_purger.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  group('Secure delete & post-purge VACUUM (Phase 1.4)', () {
    test('AppDatabase enables PRAGMA secure_delete = ON', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final rows = await db.customSelect('PRAGMA secure_delete;').get();
      expect(rows, hasLength(1));
      expect(rows.first.data['secure_delete'], 1);
    });

    test('TrashAutoPurger purges expired notes and runs VACUUM cleanly',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);

      final now = DateTime(2026, 11, 27);
      final note = await noteRepo.createNote(
        title: 'Expired secret',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );
      await noteRepo.softDelete(note.id);

      final purger = TrashAutoPurger(
        db,
        clock: () => now.add(const Duration(days: 31)),
      );
      final result = await purger.purgeExpired();
      expect(result.notes, 1);

      final remaining = await noteRepo.getNoteById(note.id);
      expect(remaining, isNull);
    });
  });
}
