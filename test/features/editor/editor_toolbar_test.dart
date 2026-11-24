import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/editor/editor_toolbar.dart';

void main() {
  group('NookBlocksMenu', () {
    testWidgets(
        'renders all block options (Heading 1-3, lists, checkbox, quote)',
        (tester) async {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: 'Test line'),
          ],
        ),
      );
      final editorState = EditorState(document: document);
      final selection = Selection.collapsed(
        Position(path: const [0], offset: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileToolbarTheme(
              child: NookBlocksMenu(
                editorState: editorState,
                selection: selection,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Heading 2'), findsOneWidget);
      expect(find.text('Heading 3'), findsOneWidget);
      expect(find.text('Bulleted list'), findsOneWidget);
      expect(find.text('Numbered list'), findsOneWidget);
      expect(find.text('Checkbox'), findsOneWidget);
      expect(find.text('Quote'), findsOneWidget);
    });

    testWidgets('tapping Heading 1 formats the current node to heading level 1',
        (tester) async {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: 'Heading line'),
          ],
        ),
      );
      final editorState = EditorState(document: document);
      final selection = Selection.collapsed(
        Position(path: const [0], offset: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MobileToolbarTheme(
              child: NookBlocksMenu(
                editorState: editorState,
                selection: selection,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Heading 1'));
      await tester.pumpAndSettle();

      final node = editorState.getNodeAtPath(const [0]);
      expect(node?.type, equals(HeadingBlockKeys.type));
      expect(node?.attributes[HeadingBlockKeys.level], equals(1));
    });
  });

  group('buildMobileToolbarItems', () {
    testWidgets('returns blocks menu, doodle action, and text decoration item',
        (tester) async {
      final document = Document.blank(withInitialText: true);
      final editorState = EditorState(document: document);
      bool doodleTriggered = false;

      late List<MobileToolbarItem> items;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              items = buildMobileToolbarItems(
                context: context,
                editorState: editorState,
                onInsertDoodle: () => doodleTriggered = true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(items.length, greaterThanOrEqualTo(8));
      expect(doodleTriggered, isFalse);
    });
  });
}
