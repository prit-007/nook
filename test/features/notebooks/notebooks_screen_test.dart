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

    await tester.enterText(find.byType(TextField).first, 'New Notebook');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('New Notebook'), findsOneWidget);
  });

  testWidgets('long press shows move-to-bin dialog', (tester) async {
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

    expect(find.text('Move Notebook to Bin?'), findsOneWidget);
  });

  testWidgets('dialog asks about notes', (tester) async {
    await insertNotebook(name: 'With Content');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('With Content'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('With Content'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
          'Do you want to move the notes in this notebook to the bin too?'),
      findsOneWidget,
    );
  });

  testWidgets('dialog has two choices: notebook only and with notes',
      (tester) async {
    await insertNotebook(name: 'Choice');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Choice'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Choice'));
    await tester.pumpAndSettle();

    expect(find.text('Notebook only'), findsOneWidget);
    expect(find.text('Notes too'), findsOneWidget);
  });

  testWidgets('dialog has cancel button', (tester) async {
    await insertNotebook(name: 'Cancellable');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Cancellable'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Cancellable'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('"Notebook only" soft-deletes notebook but keeps notes active',
      (tester) async {
    final nbRepo = NotebookRepository(db);
    final nb =
        await nbRepo.createNotebook(name: 'Notebook Only', colorSeed: '#FFF');
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: const Value('note-keep'),
            title: const Value('Active Note'),
            type: NoteType.text,
            deviceOriginId: 'local',
            notebookId: Value(nb.id),
          ),
        );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Notebook Only'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Notebook Only'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notebook only'));
    await tester.pumpAndSettle();

    // Notebook should be soft-deleted.
    final deletedNbs = await nbRepo.getDeletedNotebooks();
    expect(deletedNbs, hasLength(1));

    // Note should still be active (not soft-deleted).
    final activeNotes = await (db.select(db.notes)
          ..where((t) => t.deleted.equals(false)))
        .get();
    expect(activeNotes, hasLength(1));
    expect(activeNotes.first.id, 'note-keep');
  });

  testWidgets('"Notes too" soft-deletes both notebook and notes',
      (tester) async {
    final nbRepo = NotebookRepository(db);
    final nb = await nbRepo.createNotebook(name: 'All Gone', colorSeed: '#FFF');
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: const Value('note-kill'),
            title: const Value('Doomed Note'),
            type: NoteType.text,
            deviceOriginId: 'local',
            notebookId: Value(nb.id),
          ),
        );

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('All Gone'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('All Gone'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes too'));
    await tester.pumpAndSettle();

    // Notebook should be soft-deleted.
    final deletedNbs = await nbRepo.getDeletedNotebooks();
    expect(deletedNbs, hasLength(1));

    // Note should also be soft-deleted.
    final deletedNotes =
        await (db.select(db.notes)..where((t) => t.deleted.equals(true))).get();
    expect(deletedNotes, hasLength(1));
    expect(deletedNotes.first.id, 'note-kill');
  });

  testWidgets('cancel keeps notebook in grid', (tester) async {
    await insertNotebook(name: 'Safe');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Safe'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Safe'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Safe'), findsOneWidget);
    final repo = NotebookRepository(db);
    final active = await repo.getAllNotebooks();
    expect(active, hasLength(1));
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

    await tester.tap(find.text('Notebook only'));
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

    await tester.tap(find.text('Notebook only'));
    await tester.pumpAndSettle();

    final repo = NotebookRepository(db);
    final deleted = await repo.getDeletedNotebooks();
    expect(deleted, hasLength(1));
    expect(deleted.first.name, 'Binned');

    final active = await repo.getAllNotebooks();
    expect(active, isEmpty);
  });
}
