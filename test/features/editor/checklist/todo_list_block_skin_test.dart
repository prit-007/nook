import 'dart:convert';

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

const nookCheckboxKey = Key('nook-todo-checkbox');

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

String todoDoc({required bool firstChecked, required bool secondChecked}) {
  final doc = Document(
    root: Node(
      type: 'page',
      children: [
        paragraphNode(text: 'Intro line one'),
        paragraphNode(text: 'Intro line two'),
        paragraphNode(text: 'Intro line three'),
        todoListNode(checked: firstChecked, text: 'First task'),
        todoListNode(checked: secondChecked, text: 'Second task'),
      ],
    ),
  );
  return jsonEncode(doc.toJson());
}

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

  Future<String> createNoteWith(String content) async {
    final note = await noteRepo.createNote(
      title: '',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    await noteRepo.updateContent(note.id, deltaContent: content);
    return note.id;
  }

  Future<void> pumpEditor(WidgetTester tester, String noteId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: NoteEditorScreen(noteId: noteId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder checkboxInRowOf(String text) {
    final row = find
        .ancestor(
          of: find.text(text, findRichText: true),
          matching: find.byType(Row),
        )
        .first;
    return find.descendant(
      of: row,
      matching: find.byKey(nookCheckboxKey),
    );
  }

  Finder checkIconInRowOf(String text) {
    final row = find
        .ancestor(
          of: find.text(text, findRichText: true),
          matching: find.byType(Row),
        )
        .first;
    return find.descendant(
      of: row,
      matching: find.byIcon(Icons.check),
    );
  }

  testWidgets('renders a custom re-skinned checkbox for each todo item',
      (tester) async {
    final noteId = await createNoteWith(
      todoDoc(firstChecked: true, secondChecked: false),
    );
    await pumpEditor(tester, noteId);

    expect(find.byKey(nookCheckboxKey), findsNWidgets(2));
    expect(checkboxInRowOf('First task'), findsOneWidget);
    expect(checkboxInRowOf('Second task'), findsOneWidget);
  });

  testWidgets('checked todo shows a Material check icon inside its row',
      (tester) async {
    final noteId = await createNoteWith(
      todoDoc(firstChecked: true, secondChecked: false),
    );
    await pumpEditor(tester, noteId);

    expect(checkIconInRowOf('First task'), findsOneWidget);
    expect(checkIconInRowOf('Second task'), findsNothing);
  });

  testWidgets('tapping an unchecked todo checkbox checks it', (tester) async {
    final noteId = await createNoteWith(
      todoDoc(firstChecked: false, secondChecked: false),
    );
    await pumpEditor(tester, noteId);

    expect(checkIconInRowOf('First task'), findsNothing);

    await tester.tap(checkboxInRowOf('First task'));
    await tester.pumpAndSettle();

    expect(checkIconInRowOf('First task'), findsOneWidget);
    expect(checkIconInRowOf('Second task'), findsNothing);
  });

  testWidgets('tapping a checked todo checkbox unchecks it', (tester) async {
    final noteId = await createNoteWith(
      todoDoc(firstChecked: true, secondChecked: false),
    );
    await pumpEditor(tester, noteId);

    expect(checkIconInRowOf('First task'), findsOneWidget);

    await tester.tap(checkboxInRowOf('First task'));
    await tester.pumpAndSettle();

    expect(checkIconInRowOf('First task'), findsNothing);
  });
}
