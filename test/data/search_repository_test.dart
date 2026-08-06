import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/search_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;
  late SearchRepository searchRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);
    searchRepo = SearchRepository(db);

    // Insert test data
    await noteRepo.createNote(
      title: 'Grocery list',
      type: NoteType.text,
      deviceOriginId: 'local',
      plainText: 'Milk, eggs, bread',
    );
    await noteRepo.createNote(
      title: 'Meeting notes',
      type: NoteType.text,
      deviceOriginId: 'local',
      plainText: 'Discuss Q3 roadmap',
    );
    await noteRepo.createNote(
      title: 'Shopping',
      type: NoteType.checklist,
      deviceOriginId: 'local',
      plainText: 'Buy new shoes',
    );
    await noteRepo.createNote(
      title: 'Doodle sketch',
      type: NoteType.doodle,
      deviceOriginId: 'local',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('SearchRepository', () {
    test('searchNotes by title finds matching notes', () async {
      final results = await searchRepo.searchNotes('Grocery');
      expect(results.length, 1);
      expect(results.first.title, 'Grocery list');
    });

    test('searchNotes by plainText finds matching notes', () async {
      final results = await searchRepo.searchNotes('roadmap');
      expect(results.length, 1);
      expect(results.first.title, 'Meeting notes');
    });

    test('searchNotes is case-insensitive', () async {
      final results = await searchRepo.searchNotes('GROCERY');
      expect(results.length, 1);
    });

    test('searchNotes returns multiple matches', () async {
      // Add another note with "Grocery" in plainText
      await noteRepo.createNote(
        title: 'Grocery budget',
        type: NoteType.text,
        deviceOriginId: 'local',
        plainText: 'Monthly grocery expenses',
      );

      final results = await searchRepo.searchNotes('Grocery');
      expect(results.length, 2);
    });

    test('searchNotes returns empty for no matches', () async {
      final results = await searchRepo.searchNotes('nonexistent');
      expect(results, isEmpty);
    });

    test('searchNotes excludes deleted notes', () async {
      final note = await noteRepo.createNote(
        title: 'Deleted note',
        type: NoteType.text,
        deviceOriginId: 'local',
        plainText: 'This will be deleted',
      );
      await noteRepo.softDelete(note.id);

      final results = await searchRepo.searchNotes('Deleted');
      expect(results, isEmpty);
    });

    test('searchNotes filters by type', () async {
      final results = await searchRepo.searchNotes(
        'Shopping',
        type: NoteType.checklist,
      );
      expect(results.length, 1);
      expect(results.first.type, NoteType.checklist);
    });

    test('searchNotes filters by type returns empty when wrong type', () async {
      final results = await searchRepo.searchNotes(
        'Shopping',
        type: NoteType.text,
      );
      expect(results, isEmpty);
    });
  });
}
