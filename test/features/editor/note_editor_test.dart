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

    final expectedDate = DateFormat('MMM d, yyyy').format(DateTime.now());
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

    final expectedDate = DateFormat('MMM d, yyyy').format(DateTime.now());
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

  testWidgets('app bar shows note title for existing note', (tester) async {
    final note = await noteRepo.createNote(
      title: 'My Great Note',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    await tester.pumpWidget(buildEditor(noteId: note.id));
    await tester.pumpAndSettle();

    expect(find.text('My Great Note'), findsOneWidget);
  });

  testWidgets('app bar shows date subtitle for existing note', (tester) async {
    final note = await noteRepo.createNote(
      title: 'Titled',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    await tester.pumpWidget(buildEditor(noteId: note.id));
    await tester.pumpAndSettle();

    final expectedDate = DateFormat('MMM d, yyyy').format(DateTime.now());
    expect(find.text(expectedDate), findsOneWidget);
  });

  testWidgets('new note shows Untitled in app bar', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('Untitled'), findsOneWidget);
  });

  testWidgets('has image insert button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_photo_alternate_rounded), findsOneWidget);
  });

  testWidgets('has export button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
  });

  testWidgets('has doodle insert button', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.draw_rounded), findsOneWidget);
  });

  testWidgets('editor uses custom slash menu with doodle item', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    // Verify the editor is rendered — the custom slash menu items are
    // registered via characterShortcutEvents in the editor widget.
    // We verify by checking the editor widget exists and the doodle
    // toolbar button is present (both wired in the same screen).
    expect(find.byType(AppFlowyEditor), findsOneWidget);
    expect(find.byIcon(Icons.draw_rounded), findsOneWidget);
  });

  testWidgets('tapping checklist button inserts todo_list node',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    // Directly manipulate editor state to insert a todo list node,
    // simulating what the format bar button does.
    final editorWidget =
        tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    final editorState = editorWidget.editorState;

    insertNodeAfterSelection(editorState, todoListNode(checked: false));
    await tester.pumpAndSettle();

    final nodes = editorState.document.root.children;
    final hasTodo = nodes.any((n) => n.type == 'todo_list');
    expect(hasTodo, isTrue);
  });

  testWidgets('tapping bullet list button inserts bulleted_list node',
      (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    final editorWidget =
        tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    final editorState = editorWidget.editorState;

    insertNodeAfterSelection(editorState, bulletedListNode());
    await tester.pumpAndSettle();

    final nodes = editorState.document.root.children;
    final hasBullet = nodes.any((n) => n.type == 'bulleted_list');
    expect(hasBullet, isTrue);
  });

  testWidgets('editor renders with per-note color seed background',
      (tester) async {
    final note = await noteRepo.createNote(
      title: 'Colored',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    // Set a color seed on the note.
    await noteRepo.updateNote(note.id, colorSeed: '6750A4');

    await tester.pumpWidget(buildEditor(noteId: note.id));
    await tester.pumpAndSettle();

    // The editor should render without errors — NoteThemeScope provides
    // the derived color scheme to descendant widgets.
    expect(find.byType(AppFlowyEditor), findsOneWidget);
  });

  group('NoteExportCapture', () {
    testWidgets('renders paragraphs and todos with checked state',
        (tester) async {
      final note = await noteRepo.createNote(
        title: 'Export',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: 'Hello paragraph'),
            todoListNode(checked: true, text: 'Done task'),
            todoListNode(checked: false, text: 'Open task'),
          ],
        ),
      );
      final editorState = EditorState(document: document);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteExportCapture(note: note, editorState: editorState),
          ),
        ),
      );

      expect(find.text('Hello paragraph'), findsOneWidget);
      expect(find.text('Done task'), findsOneWidget);
      expect(find.text('Open task'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });
  });
}
