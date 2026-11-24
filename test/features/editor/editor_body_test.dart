import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_body.dart';

void main() {
  final now = DateTime(2026, 11, 23, 14, 30);
  final testNote = Note(
    id: 'body-note-1',
    title: 'Body Sample',
    type: NoteType.text,
    pinned: false,
    locked: false,
    deleted: false,
    syncVersion: 1,
    deviceOriginId: 'local',
    createdAt: now,
    updatedAt: now,
  );

  group('insertBlockNode', () {
    test('appends node when there is no selection', () {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: 'First'),
          ],
        ),
      );
      final editorState = EditorState(document: document);
      final newNode = paragraphNode(text: 'Second');

      final inserted = insertBlockNode(editorState, newNode);
      expect(inserted, isNotNull);
      expect(editorState.document.root.children.length, equals(2));
    });

    test('inserts node after collapsed selection', () {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: 'First'),
            paragraphNode(text: 'Third'),
          ],
        ),
      );
      final editorState = EditorState(document: document);
      editorState.selection = Selection.collapsed(
        Position(path: const [0], offset: 2),
      );

      final newNode = paragraphNode(text: 'Second');
      final inserted = insertBlockNode(editorState, newNode);
      expect(inserted, isNotNull);
      expect(editorState.document.root.children.length, equals(3));
    });
  });

  group('EditorBody', () {
    testWidgets('renders AppFlowyEditor for text notes', (tester) async {
      final document = Document.blank(withInitialText: true);
      final editorState = EditorState(document: document);
      final theme = ThemeData.light();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: EditorBody(
              editorState: editorState,
              note: testNote,
              noteScheme: theme.colorScheme,
              dynamicTextTheme: theme.textTheme,
              paperStyle: NotePaperStyle.blank,
              onInsertDoodle: () {},
            ),
          ),
        ),
      );

      expect(find.byType(AppFlowyEditor), findsOneWidget);
    });

    testWidgets(
        'renders doodle prompt when note type is doodle and has no doodle block',
        (tester) async {
      final document = Document.blank(withInitialText: true);
      final editorState = EditorState(document: document);
      final theme = ThemeData.light();
      final doodleNote = testNote.copyWith(type: NoteType.doodle);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: EditorBody(
              editorState: editorState,
              note: doodleNote,
              noteScheme: theme.colorScheme,
              dynamicTextTheme: theme.textTheme,
              paperStyle: NotePaperStyle.blank,
              hasDoodleBlock: false,
              onInsertDoodle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Add a drawing to this note'), findsOneWidget);
    });
  });
}
