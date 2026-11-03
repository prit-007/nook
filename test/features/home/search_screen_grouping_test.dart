import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
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

    testWidgets('quick filter chips filter results by type and pin',
        (tester) async {
      final noteRepo = NoteRepository(db);
      await noteRepo.createNote(
        title: 'Work note',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'some text',
      );
      await noteRepo.createNote(
        title: 'Weekly grocery list',
        type: NoteType.checklist,
        deviceOriginId: 'd1',
      );
      final sketch = await noteRepo.createNote(
        title: 'Secret sketch',
        type: NoteType.doodle,
        deviceOriginId: 'd1',
        plainText: 'Doodle drawing',
      );
      await noteRepo.updateNote(sketch.id, pinned: true);

      await tester.pumpWidget(buildSearch());
      await tester.pumpAndSettle();

      // Tap Checklists chip
      await tester.tap(find.text('Checklists'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly grocery list'), findsOneWidget);
      expect(find.text('Work note'), findsNothing);
      expect(find.text('Secret sketch'), findsNothing);

      // Tap Doodles chip
      await tester.tap(find.text('Doodles'));
      await tester.pumpAndSettle();

      expect(find.text('Secret sketch'), findsOneWidget);
      expect(find.text('Weekly grocery list'), findsNothing);
      expect(find.text('Work note'), findsNothing);

      // Tap Pinned chip
      await tester.tap(find.text('Pinned'));
      await tester.pumpAndSettle();

      expect(find.text('Secret sketch'), findsOneWidget);
      expect(find.text('Weekly grocery list'), findsNothing);

      // Tap Pinned again to deselect
      await tester.tap(find.text('Pinned'));
      await tester.pumpAndSettle();

      // Doodle filter is still active, so Secret sketch is still shown
      expect(find.text('Secret sketch'), findsOneWidget);

      // Deselect Doodles filter
      await tester.tap(find.text('Doodles'));
      await tester.pumpAndSettle();

      // Returns to initial search prompt when no filter is active and query is empty
      expect(
        find.text('Type words, tags, or select a filter above'),
        findsOneWidget,
      );
    });

    testWidgets('clear button resets search field query', (tester) async {
      final noteRepo = NoteRepository(db);
      await noteRepo.createNote(
        title: 'Shopping Plan',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'buy groceries',
      );

      await tester.pumpWidget(buildSearch());
      await typeQuery(tester, 'Shopping');

      expect(find.text('Shopping Plan'), findsOneWidget);

      // Tap clear button
      final clearButtonFinder = find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedCancel01,
      );
      expect(clearButtonFinder, findsOneWidget);
      await tester.tap(clearButtonFinder);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });
  });
}
