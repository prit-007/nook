import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/repositories/search_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  group('Structured search filters (Phase 5)', () {
    test('supports tag:, in:, is:, before:, and after: filters', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final noteRepo = NoteRepository(db);
      final nbRepo = NotebookRepository(db);
      final tagRepo = TagRepository(db);
      final searchRepo = SearchRepository(db);

      final workNb =
          await nbRepo.createNotebook(name: 'Work', colorSeed: '#6750A4');
      final n1 = await noteRepo.createNote(
        id: 'sf-1',
        title: 'Sprint Planning',
        plainText: 'Architecture roadmap',
        type: NoteType.checklist,
        notebookId: workNb.id,
        deviceOriginId: 'dev-1',
        createdAt: DateTime.utc(2026, 11, 10),
      );
      await noteRepo.updateNote(n1.id, pinned: true);
      await tagRepo.assignTagByName(n1.id, 'urgent');

      await noteRepo.createNote(
        id: 'sf-2',
        title: 'Grocery List',
        plainText: 'Milk and bread',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        createdAt: DateTime.utc(2026, 11, 1),
      );

      final byTagAndNb = await searchRepo.searchNotesWithFilters(
        'tag:urgent in:Work is:pinned is:checklist',
      );
      expect(byTagAndNb.map((n) => n.id), equals(['sf-1']));

      final byDateAndText = await searchRepo.searchNotesWithFilters(
        'roadmap after:2026-11-05 before:2026-12-01',
      );
      expect(byDateAndText.map((n) => n.id), equals(['sf-1']));

      final excludedByDate = await searchRepo.searchNotesWithFilters(
        'roadmap before:2026-11-05',
      );
      expect(excludedByDate, isEmpty);
    });
  });
}
