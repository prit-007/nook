import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_body.dart';
import 'package:nook/features/editor/widgets/editor_outline.dart';

void main() {
  final now = DateTime(2026, 11, 23, 16, 0);
  final testNote = Note(
    id: 'reading-note-1',
    title: 'Reading & Focus Test',
    type: NoteType.text,
    pinned: false,
    locked: false,
    deleted: false,
    syncVersion: 1,
    deviceOriginId: 'local',
    createdAt: now,
    updatedAt: now,
  );

  group('Step 5 — Reading & Focus: Document Outline', () {
    test('extractHeadings finds all H1, H2, H3 nodes with levels and text', () {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            headingNode(level: 1, text: 'Introduction'),
            paragraphNode(text: 'Some intro body text.'),
            headingNode(level: 2, text: 'Background'),
            paragraphNode(text: 'Background paragraph.'),
            headingNode(level: 3, text: 'Technical Details'),
            headingNode(level: 1, text: 'Conclusion'),
          ],
        ),
      );

      final headings = extractHeadings(document);
      expect(headings.length, equals(4));
      expect(headings[0].text, equals('Introduction'));
      expect(headings[0].level, equals(1));
      expect(headings[1].text, equals('Background'));
      expect(headings[1].level, equals(2));
      expect(headings[2].text, equals('Technical Details'));
      expect(headings[2].level, equals(3));
      expect(headings[3].text, equals('Conclusion'));
      expect(headings[3].level, equals(1));
    });

    testWidgets('EditorOutlineSheet renders headings and handles selection',
        (tester) async {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            headingNode(level: 1, text: 'Chapter One'),
            headingNode(level: 2, text: 'Section A'),
          ],
        ),
      );

      HeadingEntry? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorOutlineSheet(
              document: document,
              onSelect: (entry) {
                selected = entry;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Document Outline'), findsOneWidget);
      expect(find.text('Chapter One'), findsOneWidget);
      expect(find.text('Section A'), findsOneWidget);

      await tester.tap(find.text('Section A'));
      expect(selected?.text, equals('Section A'));
      expect(selected?.level, equals(2));
    });
  });

  group('Step 5 — Reading & Focus: Read-Only Mode in EditorBody', () {
    testWidgets('EditorBody respects readOnly parameter', (tester) async {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: 'Read-only content'),
          ],
        ),
      );
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
              readOnly: true,
              onInsertDoodle: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final appflowyFinder = find.byType(AppFlowyEditor);
      expect(appflowyFinder, findsOneWidget);
      final appflowy = tester.widget<AppFlowyEditor>(appflowyFinder);
      expect(appflowy.editable, isFalse);
    });
  });
}
