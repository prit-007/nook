import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/widgets/note_options_sheet.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> insertNote(String id) async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            title: const Value('Test Note'),
            type: NoteType.text,
            deviceOriginId: 'local',
          ),
        );
    return id;
  }

  Widget buildSheet({String noteId = 'test-note'}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: NoteOptionsSheet(
              noteId: noteId,
              onNotebookChanged: (_) {},
              onTagsChanged: (_) {},
              onColorChanged: (_) {},
              onLockedChanged: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  group('NoteOptionsSheet inline creation', () {
    testWidgets('shows create notebook button when no notebooks exist',
        (tester) async {
      await insertNote('test-note');

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      expect(find.text('New notebook'), findsOneWidget);
    });

    testWidgets('tapping new notebook shows inline text field', (tester) async {
      await insertNote('test-note');

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      await tester.tap(find.text('New notebook'));
      await tester.pumpAndSettle();

      // Should show a text field for the notebook name
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('creating notebook adds it to list and auto-selects',
        (tester) async {
      await insertNote('test-note');

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      // Tap create button
      await tester.tap(find.text('New notebook'));
      await tester.pumpAndSettle();

      // Enter name
      await tester.enterText(
        find.byType(TextField).first,
        'My New Notebook',
      );
      await tester.pumpAndSettle();

      // Scroll to and tap the Create button
      final createButton = find.text('Create');
      await tester.scrollUntilVisible(
        createButton,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Notebook should appear in the list
      expect(find.text('My New Notebook'), findsOneWidget);
    });

    testWidgets('shows create tag button when no tags exist', (tester) async {
      await insertNote('test-note');

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      expect(find.text('New tag'), findsOneWidget);
    });

    testWidgets('creating tag adds it to list and auto-selects',
        (tester) async {
      await insertNote('test-note');

      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      // Tap create tag button
      await tester.tap(find.text('New tag'));
      await tester.pumpAndSettle();

      // Enter name
      await tester.enterText(
        find.byType(TextField).first,
        'urgent',
      );
      await tester.pumpAndSettle();

      // Scroll to and tap the Create button
      final createButton = find.text('Create');
      await tester.scrollUntilVisible(
        createButton,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Tag should appear in the list
      expect(find.text('urgent'), findsOneWidget);
    });
  });
}
