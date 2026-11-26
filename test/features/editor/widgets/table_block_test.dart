import 'package:appflowy_editor/appflowy_editor.dart'
    hide TableBlockComponentBuilder, TableBlockComponentWidget, tableMenuItem;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/theme/note_theme_scope.dart';
import 'package:nook/features/editor/widgets/table_block.dart';

void main() {
  group('Table block', () {
    test(
        'tableBlockNode(rows, cols) generates AppFlowy Node with type and dimensions',
        () {
      final node = tableBlockNode(2, 3);
      expect(node.type, equals(TableBlockKeys.type));
      expect(node.attributes[TableBlockKeys.rowsLen], equals(2));
      expect(node.attributes[TableBlockKeys.colsLen], equals(3));
      expect(node.children.length, equals(6));

      // Check structure of each cell
      for (final cell in node.children) {
        expect(cell.type, equals(TableCellBlockKeys.type));
        expect(cell.attributes.containsKey(TableCellBlockKeys.rowPosition),
            isTrue);
        expect(cell.attributes.containsKey(TableCellBlockKeys.colPosition),
            isTrue);
        final r = cell.attributes[TableCellBlockKeys.rowPosition] as int;
        final c = cell.attributes[TableCellBlockKeys.colPosition] as int;
        expect(r >= 0 && r < 2, isTrue);
        expect(c >= 0 && c < 3, isTrue);
        expect(cell.children.isNotEmpty, isTrue);
      }
    });

    test('tableBlockNode populates initial data when provided', () {
      final node = tableBlockNode(2, 2, [
        ['R0C0', 'R0C1'],
        ['R1C0', 'R1C1'],
      ]);
      expect(node.children.length, equals(4));

      final firstCell = node.children.firstWhere(
        (c) =>
            c.attributes[TableCellBlockKeys.rowPosition] == 0 &&
            c.attributes[TableCellBlockKeys.colPosition] == 0,
      );
      expect(firstCell.children.first.delta?.toPlainText(), equals('R0C0'));

      final lastCell = node.children.firstWhere(
        (c) =>
            c.attributes[TableCellBlockKeys.rowPosition] == 1 &&
            c.attributes[TableCellBlockKeys.colPosition] == 1,
      );
      expect(lastCell.children.first.delta?.toPlainText(), equals('R1C1'));
    });

    test('tableMenuItem is defined and inserts table node', () {
      expect(tableMenuItem, isNotNull);
      expect(tableMenuItem.name, equals('Table'));
      expect(tableMenuItem.keywords, contains('table'));
    });

    test('TableBlockComponentBuilder validates correct table nodes', () {
      final builder = TableBlockComponentBuilder();
      final validNode = tableBlockNode(2, 2);
      expect(builder.validate(validNode), isTrue);

      final invalidNode = Node(
        type: TableBlockKeys.type,
        attributes: {},
      );
      expect(builder.validate(invalidNode), isFalse);
    });

    testWidgets(
        'TableBlockComponentBuilder and TableBlockComponentWidget render a grid of cells',
        (tester) async {
      final node = tableBlockNode(2, 2, [
        ['Alpha', 'Beta'],
        ['Gamma', 'Delta'],
      ]);
      final document = Document(
        root: Node(
          type: 'page',
          children: [node],
        ),
      );
      final editorState = EditorState(document: document);
      final testScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

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
                  TableBlockKeys.type: TableBlockComponentBuilder(),
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TableBlockComponentWidget), findsOneWidget);

      // Verify grid of cells rendered with their text
      expect(find.text('Alpha', findRichText: true), findsOneWidget);
      expect(find.text('Beta', findRichText: true), findsOneWidget);
      expect(find.text('Gamma', findRichText: true), findsOneWidget);
      expect(find.text('Delta', findRichText: true), findsOneWidget);

      // Verify action buttons exist with HugeIcons, touch targets >= 48dp, font floor >= 12sp
      expect(find.text('Add row'), findsOneWidget);
      expect(find.text('Add column'), findsOneWidget);

      // Verify HugeIcons used
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAdd01),
        findsAtLeastNWidgets(1),
      );

      // Verify touch targets >= 48x48
      final addRowTarget =
          tester.getSize(find.widgetWithText(InkWell, 'Add row'));
      expect(addRowTarget.height, greaterThanOrEqualTo(48.0));
      expect(addRowTarget.width, greaterThanOrEqualTo(48.0));

      final addColTarget =
          tester.getSize(find.widgetWithText(InkWell, 'Add column'));
      expect(addColTarget.height, greaterThanOrEqualTo(48.0));
      expect(addColTarget.width, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Tapping Add row and Add column updates table dimensions',
        (tester) async {
      final node = tableBlockNode(1, 2, [
        ['Cell 1', 'Cell 2'],
      ]);
      final document = Document(
        root: Node(
          type: 'page',
          children: [node],
        ),
      );
      final editorState = EditorState(document: document);
      final testScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

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
                  TableBlockKeys.type: TableBlockComponentBuilder(),
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(node.attributes[TableBlockKeys.rowsLen], equals(1));
      await tester.tap(find.text('Add row'));
      await tester.pumpAndSettle();
      expect(node.attributes[TableBlockKeys.rowsLen], equals(2));

      expect(node.attributes[TableBlockKeys.colsLen], equals(2));
      await tester.tap(find.text('Add column'));
      await tester.pumpAndSettle();
      expect(node.attributes[TableBlockKeys.colsLen], equals(3));
    });
  });
}
