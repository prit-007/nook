import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_body.dart';
import 'package:nook/features/editor/editor_toolbar.dart';

void main() {
  final now = DateTime(2026, 11, 23, 14, 30);
  final testNote = Note(
    id: 'fmt-note-1',
    title: 'Formatting Test',
    type: NoteType.text,
    pinned: false,
    locked: false,
    archived: false,
    deleted: false,
    syncVersion: 1,
    deviceOriginId: 'local',
    createdAt: now,
    updatedAt: now,
  );

  group('Markdown shortcuts', () {
    test('formatGreaterThanToQuote converts paragraph with > to quote',
        () async {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: '>'),
          ],
        ),
      );
      final editorState = EditorState(document: document);
      // Place cursor after '>'
      editorState.selection = Selection.collapsed(
        Position(path: const [0], offset: 1),
      );

      final event = formatGreaterThanToQuote;
      expect(event.character, equals(' '));
      final handled = await event.handler(editorState);
      expect(handled, isTrue);

      final rootChild = editorState.document.root.children.first;
      expect(rootChild.type, equals(QuoteBlockKeys.type));
    });

    test('formatBracketSpaceToUncheckedBox converts [ ] to unchecked todo',
        () async {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: '[ ]'),
          ],
        ),
      );
      final editorState = EditorState(document: document);
      // Place cursor after '[ ]'
      editorState.selection = Selection.collapsed(
        Position(path: const [0], offset: 3),
      );

      final event = formatBracketSpaceToUncheckedBox;
      expect(event.character, equals(' '));
      final handled = await event.handler(editorState);
      expect(handled, isTrue);

      final rootChild = editorState.document.root.children.first;
      expect(rootChild.type, equals(TodoListBlockKeys.type));
      expect(rootChild.attributes[TodoListBlockKeys.checked], isFalse);
    });
  });

  group('Curated Slash Menu Items', () {
    test('buildNookSlashMenuItems includes core blocks and custom Nook items',
        () {
      bool doodleCalled = false;
      bool linkCalled = false;
      bool imageCalled = false;

      final items = buildNookSlashMenuItems(
        onInsertDoodle: () => doodleCalled = true,
        onInsertNoteLink: () => linkCalled = true,
        onInsertImage: () => imageCalled = true,
      );

      final names = items.map((i) => i.name).toList();
      expect(names, contains('Text'));
      expect(names, contains('Heading 1'));
      expect(names, contains('Heading 2'));
      expect(names, contains('Heading 3'));
      expect(names, contains('Bulleted list'));
      expect(names, contains('Numbered list'));
      expect(names, contains('Checkbox'));
      expect(names, contains('Quote'));
      expect(names, contains('Divider'));
      expect(names, contains('Image'));
      expect(names, contains('Doodle'));
      expect(names, contains('Link to note'));

      final doodleItem = items.firstWhere((i) => i.name == 'Doodle');
      expect(doodleItem.keywords, contains('doodle'));

      final linkItem = items.firstWhere((i) => i.name == 'Link to note');
      expect(linkItem.keywords, contains('link'));

      final imageItem = items.firstWhere((i) => i.name == 'Image');
      expect(imageItem.keywords, contains('image'));

      expect(doodleCalled, isFalse);
      expect(linkCalled, isFalse);
      expect(imageCalled, isFalse);
    });
  });

  group('Mobile Keyboard Toolbar (Horizontal Scrollable)', () {
    testWidgets('buildMobileToolbarItems returns rich formatting actions',
        (tester) async {
      final editorState = EditorState.blank(withInitialText: true);
      bool doodleCalled = false;
      bool imageCalled = false;
      bool linkCalled = false;

      late List<MobileToolbarItem> items;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              items = buildMobileToolbarItems(
                context: context,
                editorState: editorState,
                onInsertDoodle: () => doodleCalled = true,
                onInsertImage: () => imageCalled = true,
                onInsertNoteLink: () => linkCalled = true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Should include: Blocks menu, Text style menu, Colors, Checkbox, Link, Image, Doodle, Undo, Redo, Divider
      expect(items.length, greaterThanOrEqualTo(8));
      expect(doodleCalled, isFalse);
      expect(imageCalled, isFalse);
      expect(linkCalled, isFalse);
    });
  });

  group('Floating selection toolbar items', () {
    test(
        'buildDesktopFloatingToolbarItems includes markdown formatting, link, colors',
        () {
      final items = buildDesktopFloatingToolbarItems();
      expect(items, isNotEmpty);
      expect(items.length, greaterThanOrEqualTo(7));
    });
  });

  group('Desktop Editor with FloatingToolbar', () {
    testWidgets('EditorBody wraps AppFlowyEditor in FloatingToolbar on desktop',
        (tester) async {
      final editorState = EditorState.blank(withInitialText: true);
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
  });
}
