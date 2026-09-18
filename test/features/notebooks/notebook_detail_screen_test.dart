import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/notebooks/notebook_detail_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> createNotebook(String name) async {
    final repo = NotebookRepository(db);
    final nb = await repo.createNotebook(name: name, colorSeed: '#FF0000');
    return nb.id;
  }

  Future<void> insertNote(String id, {String? notebookId}) async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            title: Value('Note $id'),
            type: NoteType.text,
            deviceOriginId: 'local',
            notebookId: Value(notebookId),
          ),
        );
  }

  Widget buildScreen(String notebookId) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: NotebookDetailScreen(notebookId: notebookId),
      ),
    );
  }

  group('NotebookDetailScreen', () {
    testWidgets('empty state shows notes-in-notebook message', (tester) async {
      final nbId = await createNotebook('Empty Notebook');

      await tester.pumpWidget(buildScreen(nbId));
      await tester.pumpAndSettle();

      expect(find.text('No notes in this collection'), findsOneWidget);
    });

    testWidgets('FAB for adding notes is visible', (tester) async {
      final nbId = await createNotebook('My Notebook');

      await tester.pumpWidget(buildScreen(nbId));
      await tester.pumpAndSettle();

      // There should be a FAB or action button to add notes
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is FloatingActionButton ||
              (w is IconButton &&
                  w.tooltip != null &&
                  w.tooltip!.toLowerCase().contains('add')),
        ),
        findsWidgets,
      );
    });

    testWidgets('existing notes in notebook are displayed', (tester) async {
      final nbId = await createNotebook('With Notes');
      await insertNote('n1', notebookId: nbId);
      await insertNote('n2', notebookId: nbId);

      await tester.pumpWidget(buildScreen(nbId));
      await tester.pumpAndSettle();

      expect(find.textContaining('Note n1'), findsWidgets);
      expect(find.textContaining('Note n2'), findsWidgets);
    });
  });
}
