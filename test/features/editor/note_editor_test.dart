import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

  testWidgets('renders floating header with today date', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    final expectedDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
    expect(find.text(expectedDate), findsOneWidget);
  });

  testWidgets('renders floating header with date for existing note',
      (tester) async {
    final note = await noteRepo.createNote(
      title: 'Existing',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    await tester.pumpWidget(buildEditor(noteId: note.id));
    await tester.pumpAndSettle();

    final expectedDate = DateFormat('MMMM d, yyyy').format(DateTime.now());
    expect(find.text(expectedDate), findsOneWidget);
  });

  testWidgets('existing note exposes hero tag matching note id',
      (tester) async {
    final note = await noteRepo.createNote(
      title: 'Hero note',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    await tester.pumpWidget(buildEditor(noteId: note.id));
    await tester.pumpAndSettle();

    final heroes = tester.widgetList<Hero>(find.byType(Hero));
    expect(heroes.map((h) => h.tag), contains('note-${note.id}'));
  });

  testWidgets('new note has no hero (no source card)', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.byType(Hero), findsNothing);
  });

  testWidgets('shows AppFlowyEditor widget', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byType(AppFlowyEditor), findsOneWidget);
  });

  testWidgets('has a back button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('has pin/unpin button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);
  });

  testWidgets('has overflow menu button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
  });

  testWidgets('overflow menu shows Note options sheet', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Note options'), findsOneWidget);
  });

  testWidgets('note options sheet has Notebook section', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Notebook'), findsOneWidget);
  });

  testWidgets('note options sheet has Tags section', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Tags'), findsOneWidget);
  });

  testWidgets('note options sheet has Color section', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Color'), findsOneWidget);
  });

  testWidgets('pin toggle changes icon', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.push_pin_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
  });
}
