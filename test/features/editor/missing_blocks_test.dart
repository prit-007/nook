import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_body.dart';
import 'package:nook/features/editor/editor_toolbar.dart';
import 'package:nook/features/editor/widgets/callout_block.dart';
import 'package:nook/features/editor/widgets/code_block.dart';
import 'package:nook/features/editor/widgets/collapsible_block.dart';

void main() {
  final now = DateTime(2026, 11, 23, 14, 30);
  final testNote = Note(
    id: 'blocks-note-1',
    title: 'Missing Blocks Test',
    type: NoteType.text,
    pinned: false,
    locked: false,
    deleted: false,
    syncVersion: 1,
    deviceOriginId: 'local',
    createdAt: now,
    updatedAt: now,
  );

  group('Callout block', () {
    test('calloutNode creates node with callout type, icon, and text', () {
      final node =
          calloutNode(text: 'Note this important detail', icon: 'info');
      expect(node.type, equals(CalloutBlockKeys.type));
      expect(node.attributes[CalloutBlockKeys.icon], equals('info'));
      expect(node.delta?.toPlainText(), equals('Note this important detail'));
    });

    testWidgets('Callout block renders leading icon and styled container',
        (tester) async {
      final node = calloutNode(text: 'Pro tip for users', icon: 'bulb');
      final document = Document(
        root: Node(
          type: 'page',
          children: [node],
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
              onInsertDoodle: () {},
            ),
          ),
        ),
      );

      expect(
          find.text('Pro tip for users', findRichText: true), findsOneWidget);
    });
  });

  group('Code block', () {
    test('codeBlockNode creates node with code type, language, and content',
        () {
      final node = codeBlockNode(
        code: 'void main() => print("Hello");',
        language: 'dart',
      );
      expect(node.type, equals(CodeBlockKeys.type));
      expect(node.attributes[CodeBlockKeys.language], equals('dart'));
      expect(
          node.delta?.toPlainText(), equals('void main() => print("Hello");'));
    });

    testWidgets('Code block renders language badge and copy action',
        (tester) async {
      final node = codeBlockNode(
        code: 'final x = 42;',
        language: 'dart',
      );
      final document = Document(
        root: Node(
          type: 'page',
          children: [node],
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
              onInsertDoodle: () {},
            ),
          ),
        ),
      );

      expect(find.text('dart'), findsOneWidget);
      expect(find.text('final x = 42;', findRichText: true), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedCopy01),
        findsOneWidget,
      );
    });
  });

  group('Collapsible block (toggle section)', () {
    test('collapsibleNode creates node with collapsed attribute', () {
      final node = collapsibleNode(title: 'Toggle Section', collapsed: true);
      expect(node.type, equals(CollapsibleBlockKeys.type));
      expect(node.attributes[CollapsibleBlockKeys.collapsed], isTrue);
      expect(node.delta?.toPlainText(), equals('Toggle Section'));
    });

    testWidgets('Collapsible block renders toggle arrow and title',
        (tester) async {
      final node = collapsibleNode(title: 'Advanced Details', collapsed: false);
      final document = Document(
        root: Node(
          type: 'page',
          children: [node],
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
              onInsertDoodle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Advanced Details', findRichText: true), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedArrowDown01),
        findsOneWidget,
      );
    });
  });

  group('Slash menu has all new blocks', () {
    test(
        'buildNookSlashMenuItems includes callout, code, collapsible, divider, table',
        () {
      final items = buildNookSlashMenuItems(
        onInsertDoodle: () {},
      );

      final names = items.map((i) => i.name).toList();
      expect(names, contains('Callout'));
      expect(names, contains('Code block'));
      expect(names, contains('Collapsible section'));
      expect(names, contains('Table'));
      expect(names, contains('Divider'));
    });
  });
}
