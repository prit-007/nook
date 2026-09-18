import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/notebooks/notebooks_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScreen() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: NotebooksScreen()),
    );
  }

  Future<void> insertNotebook({
    required String name,
    String colorSeed = '#FF5722',
  }) async {
    final repo = NotebookRepository(db);
    await repo.createNotebook(name: name, colorSeed: colorSeed);
  }

  testWidgets('renders app bar title', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    expect(find.text('Collections'), findsOneWidget);
  });

  testWidgets('shows empty state when no notebooks', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    expect(find.textContaining('No collections'), findsOneWidget);
  });

  testWidgets('displays notebooks in a grid', (tester) async {
    await insertNotebook(name: 'Work');
    await insertNotebook(name: 'Personal');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets('FAB opens create notebook form', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('New Collection'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('create notebook via form sheet', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter notebook name
    await tester.enterText(find.byType(TextField).first, 'New Notebook');
    await tester.pumpAndSettle();

    // Tap save button
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Notebook should appear in grid
    expect(find.text('New Notebook'), findsOneWidget);
  });

  testWidgets('long press shows move-to-bin option', (tester) async {
    await insertNotebook(name: 'Delete Me');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delete Me'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Delete Me'));
    await tester.pumpAndSettle();

    expect(find.text('Move to Bin'), findsWidgets);
  });

  testWidgets('soft-delete notebook removes it from grid', (tester) async {
    await insertNotebook(name: 'Gone');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Gone'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Gone'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Move to Bin'));
    await tester.pumpAndSettle();

    expect(find.text('Gone'), findsNothing);
  });

  testWidgets('soft-delete notebook lands in bin', (tester) async {
    await insertNotebook(name: 'Binned');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Binned'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Binned'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Move to Bin'));
    await tester.pumpAndSettle();

    // Verify it's soft-deleted in DB (not hard-deleted).
    final repo = NotebookRepository(db);
    final deleted = await repo.getDeletedNotebooks();
    expect(deleted, hasLength(1));
    expect(deleted.first.name, 'Binned');

    // Verify it doesn't appear in active list.
    final active = await repo.getAllNotebooks();
    expect(active, isEmpty);
  });

  testWidgets('soft-delete with notes checkbox also soft-deletes notes',
      (tester) async {
    final nbRepo = NotebookRepository(db);
    final nb =
        await nbRepo.createNotebook(name: 'With Notes', colorSeed: '#FFF');
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: const Value('note-in-nb'),
            title: const Value('Child Note'),
            type: NoteType.text,
            deviceOriginId: 'local',
            notebookId: Value(nb.id),
          ),
        );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('With Notes'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('With Notes'));
    await tester.pumpAndSettle();

    // Check "Move all notes to Bin" checkbox.
    await tester.tap(find.byWidgetPredicate((w) => w is CheckboxListTile));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Move to Bin'));
    await tester.pumpAndSettle();

    // Notebook should be soft-deleted.
    final deletedNbs = await nbRepo.getDeletedNotebooks();
    expect(deletedNbs, hasLength(1));

    // Note should also be soft-deleted.
    final deletedNotes =
        await (db.select(db.notes)..where((t) => t.deleted.equals(true))).get();
    expect(deletedNotes, hasLength(1));
    expect(deletedNotes.first.id, 'note-in-nb');
  });
}
