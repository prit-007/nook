import 'package:appflowy_editor/appflowy_editor.dart'
    hide TableBlockComponentBuilder, TableBlockComponentWidget, tableMenuItem;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/note_theme_scope.dart';

export 'package:appflowy_editor/appflowy_editor.dart'
    show TableBlockKeys, TableCellBlockKeys;

/// Slash menu item inserting a [tableBlockNode] after the current selection.
final SelectionMenuItem tableMenuItem = SelectionMenuItem(
  getName: () => 'Table',
  icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
    name: 'table',
    isSelected: isSelected,
    style: style,
  ),
  keywords: ['table', 'grid', 'rows', 'columns', 'spreadsheet'],
  handler: (editorState, _, __) {
    insertNodeAfterSelection(editorState, tableBlockNode());
  },
);

/// Creates a Table [Node] with the given number of [rows] and [cols].
Node tableBlockNode([
  int rows = 2,
  int cols = 2,
  List<List<String>>? initialData,
]) {
  assert(rows > 0 && cols > 0);
  final children = <Node>[];
  for (var c = 0; c < cols; c++) {
    for (var r = 0; r < rows; r++) {
      final text = (initialData != null &&
              r < initialData.length &&
              c < initialData[r].length)
          ? initialData[r][c]
          : '';
      final cell = Node(
        type: TableCellBlockKeys.type,
        attributes: {
          TableCellBlockKeys.colPosition: c,
          TableCellBlockKeys.rowPosition: r,
        },
        children: [
          paragraphNode(delta: Delta()..insert(text)),
        ],
      );
      children.add(cell);
    }
  }

  return Node(
    type: TableBlockKeys.type,
    attributes: {
      TableBlockKeys.rowsLen: rows,
      TableBlockKeys.colsLen: cols,
    },
    children: children,
  );
}

/// Builder mapping table nodes to [TableBlockComponentWidget].
class TableBlockComponentBuilder extends BlockComponentBuilder {
  TableBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return TableBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) => actionBuilder(
        blockComponentContext,
        state,
      ),
      actionTrailingBuilder: (context, state) => actionTrailingBuilder(
        blockComponentContext,
        state,
      ),
    );
  }

  @override
  BlockComponentValidate get validate => (node) =>
      node.attributes.containsKey(TableBlockKeys.colsLen) &&
      node.attributes.containsKey(TableBlockKeys.rowsLen);
}

class TableBlockComponentWidget extends BlockComponentStatefulWidget {
  const TableBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<TableBlockComponentWidget> createState() =>
      _TableBlockComponentWidgetState();
}

class _TableBlockComponentWidgetState extends State<TableBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final tableKey = GlobalKey();
  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  late final EditorState editorState =
      Provider.of<EditorState>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    final rowsLen = node.attributes[TableBlockKeys.rowsLen] as int? ?? 1;
    final colsLen = node.attributes[TableBlockKeys.colsLen] as int? ?? 1;

    Widget child = Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6.5),
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    verticalInside: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  children: List.generate(rowsLen, (r) {
                    final isHeader = r == 0;
                    return TableRow(
                      decoration: isHeader
                          ? BoxDecoration(
                              color: scheme.surfaceContainerHigh
                                  .withValues(alpha: 0.45),
                            )
                          : null,
                      children: List.generate(colsLen, (c) {
                        return _buildCell(context, r, c);
                      }),
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Action buttons: Add Row / Add Column
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Add table row',
                button: true,
                child: InkWell(
                  onTap: () => _addRow(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAdd01,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Add row',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: 'Add table column',
                button: true,
                child: InkWell(
                  onTap: () => _addColumn(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAdd01,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Add column',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    child = Padding(
      key: tableKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
      supportTypes: const [
        BlockSelectionType.block,
      ],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }

  Widget _buildCell(BuildContext context, int row, int col) {
    final cell = node.children.where((n) {
      return n.attributes[TableCellBlockKeys.rowPosition] == row &&
          n.attributes[TableCellBlockKeys.colPosition] == col;
    }).firstOrNull;

    Widget cellContent;
    if (cell != null && cell.children.isNotEmpty) {
      cellContent = editorState.renderer.build(context, cell.children.first);
    } else {
      cellContent = const SizedBox.shrink();
    }

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(
          minWidth: 80,
          minHeight: 36,
        ),
        child: cellContent,
      ),
    );
  }

  void _addRow(BuildContext context) {
    final currentRows = node.attributes[TableBlockKeys.rowsLen] as int? ?? 1;
    final cols = node.attributes[TableBlockKeys.colsLen] as int? ?? 1;
    final newRowIndex = currentRows;

    final newCells = <Node>[];
    for (var c = 0; c < cols; c++) {
      newCells.add(
        Node(
          type: TableCellBlockKeys.type,
          attributes: {
            TableCellBlockKeys.colPosition: c,
            TableCellBlockKeys.rowPosition: newRowIndex,
          },
          children: [
            paragraphNode(),
          ],
        ),
      );
    }

    final transaction = editorState.transaction;
    transaction.updateNode(node, {
      TableBlockKeys.rowsLen: currentRows + 1,
    });
    for (final cell in newCells) {
      transaction.insertNode(node.path + [node.children.length], cell);
    }
    editorState.apply(transaction);
  }

  void _addColumn(BuildContext context) {
    final rows = node.attributes[TableBlockKeys.rowsLen] as int? ?? 1;
    final currentCols = node.attributes[TableBlockKeys.colsLen] as int? ?? 1;
    final newColIndex = currentCols;

    final newCells = <Node>[];
    for (var r = 0; r < rows; r++) {
      newCells.add(
        Node(
          type: TableCellBlockKeys.type,
          attributes: {
            TableCellBlockKeys.colPosition: newColIndex,
            TableCellBlockKeys.rowPosition: r,
          },
          children: [
            paragraphNode(),
          ],
        ),
      );
    }

    final transaction = editorState.transaction;
    transaction.updateNode(node, {
      TableBlockKeys.colsLen: currentCols + 1,
    });
    for (final cell in newCells) {
      transaction.insertNode(node.path + [node.children.length], cell);
    }
    editorState.apply(transaction);
  }

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({
    bool shiftWithBaseOffset = false,
  }) {
    return getRectsInSelection(Selection.invalid()).first;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) {
      return null;
    }
    return getRectsInSelection(
      Selection.collapsed(position),
      shiftWithBaseOffset: shiftWithBaseOffset,
    ).firstOrNull;
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) {
      return [];
    }
    final parentBox = context.findRenderObject();
    final currentBox = tableKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && currentBox is RenderBox) {
      return [
        (shiftWithBaseOffset
                ? currentBox.localToGlobal(Offset.zero, ancestor: parentBox)
                : Offset.zero) &
            currentBox.size,
      ];
    }
    return [Offset.zero & _renderBox!.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) => Selection.single(
        path: widget.node.path,
        startOffset: 0,
        endOffset: 1,
      );

  @override
  Offset localToGlobal(
    Offset offset, {
    bool shiftWithBaseOffset = false,
  }) =>
      _renderBox!.localToGlobal(offset);

  @override
  TextDirection textDirection() {
    return TextDirection.ltr;
  }
}
