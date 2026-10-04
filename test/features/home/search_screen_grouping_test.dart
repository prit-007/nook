import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/search_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSearch() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: SearchScreen()),
    );
  }

  Future<void> typeQuery(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  group('SearchScreen grouping', () {
    testWidgets('shows Notes section for FTS matches', (tester) async {
      final noteRepo = NoteRepository(db);
      await noteRepo.createNote(
        title: 'Roadmap note',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'ship the roadmap',
      );

      await tester.pumpWidget(buildSearch());
      await typeQuery(tester, 'roadmap');

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Roadmap note'), findsOneWidget);
      expect(find.text('Checklist items'), findsNothing);
    });

    testWidgets('shows Checklist items section for item-text matches',
        (tester) async {
      final noteRepo = NoteRepository(db);
      final checklistRepo = ChecklistItemRepository(db);
      final note = await noteRepo.createNote(
        title: 'Errands',
        type: NoteType.checklist,
        deviceOriginId: 'd1',
      );
      await checklistRepo.addItem(noteId: note.id, text: 'renew passport');

      await tester.pumpWidget(buildSearch());
      await typeQuery(tester, 'passport');

      expect(find.text('Checklist items'), findsOneWidget);
      expect(find.text('renew passport'), findsOneWidget);
      expect(find.text('Errands'), findsOneWidget);
    });

    testWidgets('shows both sections when both kinds match', (tester) async {
      final noteRepo = NoteRepository(db);
      final checklistRepo = ChecklistItemRepository(db);
      await noteRepo.createNote(
        title: 'passport office',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'passport office hours',
      );
      final checklistNote = await noteRepo.createNote(
        title: 'Admin',
        type: NoteType.checklist,
        deviceOriginId: 'd1',
      );
      await checklistRepo.addItem(
        noteId: checklistNote.id,
        text: 'passport photo',
      );

      await tester.pumpWidget(buildSearch());
      await typeQuery(tester, 'passport');

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Checklist items'), findsOneWidget);
    });

    testWidgets('empty state when no matches', (tester) async {
      await tester.pumpWidget(buildSearch());
      await typeQuery(tester, 'zzzz-nothing');

      expect(find.text('No results'), findsOneWidget);
    });
  });
}
