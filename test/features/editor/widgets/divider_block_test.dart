import 'package:appflowy_editor/appflowy_editor.dart'
    hide
        DividerBlockComponentBuilder,
        DividerBlockComponentWidget,
        dividerMenuItem;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/theme/note_theme_scope.dart';
import 'package:nook/features/editor/widgets/divider_block.dart';

void main() {
  group('Divider block', () {
    test('dividerBlockNode creates node with divider type', () {
      final node = dividerBlockNode();
      expect(node.type, equals(DividerBlockKeys.type));
      expect(node.children, isEmpty);
    });

    test('dividerMenuItem is defined and inserts divider node', () {
      expect(dividerMenuItem, isNotNull);
      expect(dividerMenuItem.name, equals('Divider'));
      expect(dividerMenuItem.keywords, contains('divider'));
    });

    test('DividerBlockComponentBuilder validates node and builds component',
        () {
      final builder = DividerBlockComponentBuilder();
      final validNode = dividerBlockNode();
      expect(builder.validate(validNode), isTrue);

      final invalidNode = Node(
        type: DividerBlockKeys.type,
        children: [paragraphNode()],
      );
      expect(builder.validate(invalidNode), isFalse);
    });

    testWidgets(
        'DividerBlockComponentBuilder and DividerBlockComponentWidget render a horizontal divider styled with theme border colors',
        (tester) async {
      final node = dividerBlockNode();
      final document = Document(
        root: Node(
          type: 'page',
          children: [node],
        ),
      );
      final editorState = EditorState(document: document);
      const customOutlineVariant = Color(0xFF8B5CF6);
      final testScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
      ).copyWith(
        outlineVariant: customOutlineVariant,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppFlowyEditorLocalizations.delegate,
          ],
          home: Scaffold(
            body: NoteThemeScope(
              colorScheme: testScheme,
              textTheme: Typography.material2021().black,
              child: AppFlowyEditor(
                editorState: editorState,
                blockComponentBuilders: {
                  ...standardBlockComponentBuilderMap,
                  DividerBlockKeys.type: DividerBlockComponentBuilder(),
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DividerBlockComponentWidget), findsOneWidget);
      final dividerFinder = find.byType(Divider);
      expect(dividerFinder, findsOneWidget);
      final dividerWidget = tester.widget<Divider>(dividerFinder);
      expect(dividerWidget.color, equals(customOutlineVariant));
    });
  });
}
