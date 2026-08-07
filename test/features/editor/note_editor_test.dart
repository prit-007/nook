import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/note_editor_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;

  setUp(() async {
    db = createTestDb();
    noteRepo = NoteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildEditor({String? noteId, String? type}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: NoteEditorScreen(noteId: noteId, type: type),
      ),
    );
  }

  testWidgets('renders app bar with New Note title', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.text('New Note'), findsOneWidget);
  });

  testWidgets('renders app bar with Edit Note title', (tester) async {
    final note = await noteRepo.createNote(
      title: 'Existing',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    await tester.pumpWidget(buildEditor(noteId: note.id));
    await tester.pumpAndSettle();
    expect(find.text('Edit Note'), findsOneWidget);
  });

  testWidgets('shows AppFlowyEditor widget', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byType(AppFlowyEditor), findsOneWidget);
  });

  testWidgets('has a back button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('has pin/unpin button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });

  testWidgets('has delete button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('has overflow menu button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('overflow menu shows Note options sheet', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Note options'), findsOneWidget);
  });

  testWidgets('note options sheet has Notebook section', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Notebook'), findsOneWidget);
  });

  testWidgets('note options sheet has Tags section', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Tags'), findsOneWidget);
  });

  testWidgets('note options sheet has Color section', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Color'), findsOneWidget);
  });

  testWidgets('pin toggle changes icon', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });

  testWidgets('delete shows confirmation dialog', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete Note'), findsOneWidget);
    expect(find.text('Move this note to trash?'), findsOneWidget);
  });
}
