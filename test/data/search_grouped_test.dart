import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/search_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;
  late ChecklistItemRepository checklistRepo;
  late SearchRepository searchRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);
    checklistRepo = ChecklistItemRepository(db);
    searchRepo = SearchRepository(db);

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
  });

  tearDown(() async {
    await db.close();
  });

  group('SearchRepository.searchGrouped', () {
    test('returns empty for blank query', () async {
      final results = await searchRepo.searchGrouped('   ');
      expect(results.isEmpty, isTrue);
    });

    test('FTS note matches appear under notes, not checklistItems', () async {
      final results = await searchRepo.searchGrouped('roadmap');
      expect(results.notes.map((n) => n.title), ['Meeting notes']);
      expect(results.checklistItems, isEmpty);
    });

    test('checklist item text match returns parent note + snippet', () async {
      final note = await noteRepo.createNote(
        title: 'Tasks',
        type: NoteType.checklist,
        deviceOriginId: 'local',
      );
      await checklistRepo.addItem(
          noteId: note.id, text: 'Buy anniversary gift');

      final results = await searchRepo.searchGrouped('anniversary');

      expect(results.notes, isEmpty);
      expect(results.checklistItems, hasLength(1));
      final hit = results.checklistItems.single;
      expect(hit.kind, SearchResultKind.checklistItem);
      expect(hit.note.id, note.id);
      expect(hit.snippet, 'Buy anniversary gift');
      expect(hit.checklistItemId, isNotEmpty);
    });

    test('checklist item match excluded when parent note is soft-deleted',
        () async {
      final note = await noteRepo.createNote(
        title: 'Doomed tasks',
        type: NoteType.checklist,
        deviceOriginId: 'local',
      );
      await checklistRepo.addItem(
          noteId: note.id, text: 'secret checklist item');
      await noteRepo.softDelete(note.id);

      final results = await searchRepo.searchGrouped('secret');
      expect(results.checklistItems, isEmpty);
      expect(results.notes, isEmpty);
    });

    test('LIKE wildcards in query are escaped', () async {
      final note = await noteRepo.createNote(
        title: 'Percent note',
        type: NoteType.checklist,
        deviceOriginId: 'local',
      );
      await checklistRepo.addItem(noteId: note.id, text: '100% done');
      await checklistRepo.addItem(noteId: note.id, text: 'unrelated');

      final results = await searchRepo.searchGrouped('100%');
      expect(results.checklistItems, hasLength(1));
      expect(results.checklistItems.single.snippet, '100% done');
    });

    test('type filter applies to checklist parent notes', () async {
      final checklistNote = await noteRepo.createNote(
        title: 'Filtered checklist',
        type: NoteType.checklist,
        deviceOriginId: 'local',
      );
      await checklistRepo.addItem(
        noteId: checklistNote.id,
        text: 'zebra item only in checklist',
      );

      final asChecklist = await searchRepo.searchGrouped(
        'zebra',
        type: NoteType.checklist,
      );
      expect(asChecklist.checklistItems, hasLength(1));

      final asText = await searchRepo.searchGrouped(
        'zebra',
        type: NoteType.text,
      );
      expect(asChecklist.checklistItems, hasLength(1));
      expect(asText.checklistItems, isEmpty);
    });

    test('existing searchNotes still works (regression)', () async {
      final results = await searchRepo.searchNotes('Grocery');
      expect(results.single.title, 'Grocery list');
    });
  });
}
