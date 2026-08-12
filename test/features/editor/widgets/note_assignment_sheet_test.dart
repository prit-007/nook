import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/widgets/note_assignment_sheet.dart';

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
            deviceOriginId: 'test-device',
          ),
        );
    return id;
  }

  Future<String> insertNotebook(String name) async {
    final id = 'nb-${name.toLowerCase().replaceAll(' ', '-')}';
    await db.into(db.notebooks).insert(
          NotebooksCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: '#2196F3',
          ),
        );
    return id;
  }

  Future<String> insertTag(String name) async {
    final id = 'tag-${name.toLowerCase().replaceAll(' ', '-')}';
    await db.into(db.tags).insert(
          TagsCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: '#FF5722',
          ),
        );
    return id;
  }

  Future<void> assignTag(String noteId, String tagId) async {
    await db.into(db.noteTags).insert(
          NoteTagsCompanion.insert(noteId: noteId, tagId: tagId),
        );
  }

  Widget buildSheet({
    required String noteId,
    String? currentNotebookId,
  }) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => NoteAssignmentSheet.show(
                context,
                noteId: noteId,
                currentNotebookId: currentNotebookId,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester,
      {String noteId = 'note-1', String? currentNotebookId}) async {
    await tester.pumpWidget(
        buildSheet(noteId: noteId, currentNotebookId: currentNotebookId));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.pump();
  }

  testWidgets('renders section headers', (tester) async {
    await openSheet(tester);

    expect(find.text('Notebook'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
  });

  testWidgets('shows notebooks list', (tester) async {
    await insertNotebook('Work');
    await insertNotebook('Personal');

    await openSheet(tester);

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets('shows no notebooks message when none exist', (tester) async {
    await openSheet(tester);

    expect(find.textContaining('No notebooks'), findsOneWidget);
  });

  testWidgets('shows tags list', (tester) async {
    await insertTag('important');
    await insertTag('todo');

    await openSheet(tester);

    expect(find.text('important'), findsOneWidget);
    expect(find.text('todo'), findsOneWidget);
  });

  testWidgets('shows no tags message when none exist', (tester) async {
    await openSheet(tester);

    expect(find.textContaining('No tags'), findsOneWidget);
  });

  testWidgets('highlights current notebook', (tester) async {
    final nbId = await insertNotebook('Work');

    await openSheet(tester, currentNotebookId: nbId);

    expect(find.byIcon(Icons.check), findsAtLeastNWidgets(1));
  });

  testWidgets('tapping notebook closes sheet', (tester) async {
    await insertNotebook('Work');

    await openSheet(tester);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('Notebook'), findsNothing);
  });

  testWidgets('tapping tag toggles it', (tester) async {
    await insertTag('important');

    await openSheet(tester);

    await tester.tap(find.text('important'));
    await tester.pump();

    // Tag should now be selected (check icon visible)
    expect(find.byIcon(Icons.check), findsAtLeastNWidgets(1));
  });

  testWidgets('shows already-assigned tags as selected', (tester) async {
    await insertNote('note-1');
    final tagId = await insertTag('important');
    await assignTag('note-1', tagId);

    await openSheet(tester);

    expect(find.byIcon(Icons.check), findsAtLeastNWidgets(1));
  });

  testWidgets('shows done button', (tester) async {
    await openSheet(tester);

    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('done button closes sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Notebook'), findsNothing);
  });
}
