import 'package:appflowy_editor/appflowy_editor.dart'
    hide
        DividerBlockComponentBuilder,
        DividerBlockComponentWidget,
        dividerMenuItem;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/note_theme_scope.dart';

export 'package:appflowy_editor/appflowy_editor.dart' show DividerBlockKeys;

/// Slash menu item inserting a [dividerBlockNode] after the current selection.
final SelectionMenuItem dividerMenuItem = SelectionMenuItem(
  getName: () => 'Divider',
  icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
    name: 'divider',
    isSelected: isSelected,
    style: style,
  ),
  keywords: ['divider', 'line', 'hr', 'horizontal rule', 'separator'],
  handler: (editorState, _, __) {
    insertNodeAfterSelection(editorState, dividerBlockNode());
  },
);

/// Creates a horizontal Divider [Node].
Node dividerBlockNode() {
  return Node(
    type: DividerBlockKeys.type,
  );
}

/// Builder mapping divider nodes to [DividerBlockComponentWidget].
class DividerBlockComponentBuilder extends BlockComponentBuilder {
  DividerBlockComponentBuilder({
    super.configuration,
    this.thickness = 1.0,
    this.height = 24.0,
  });

  final double thickness;
  final double height;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return DividerBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      thickness: thickness,
      height: height,
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
  BlockComponentValidate get validate => (node) => node.children.isEmpty;
}

class DividerBlockComponentWidget extends BlockComponentStatefulWidget {
  const DividerBlockComponentWidget({
    super.key,
    required super.node,
    this.thickness = 1.0,
    this.height = 24.0,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  final double thickness;
  final double height;

  @override
  State<DividerBlockComponentWidget> createState() =>
      _DividerBlockComponentWidgetState();
}

class _DividerBlockComponentWidgetState
    extends State<DividerBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final dividerKey = GlobalKey();
  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    final borderColor = scheme.outlineVariant;

    Widget child = Container(
      height: widget.height,
      alignment: Alignment.center,
      child: Divider(
        color: borderColor,
        thickness: widget.thickness,
        height: widget.height,
      ),
    );

    child = Padding(
      key: dividerKey,
      padding: padding,
      child: child,
    );

    final editorState = Provider.of<EditorState>(context, listen: false);

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
        BlockSelectionType.cursor,
        BlockSelectionType.selection,
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
    final dividerBox = dividerKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && dividerBox is RenderBox) {
      return [
        (shiftWithBaseOffset
                ? dividerBox.localToGlobal(Offset.zero, ancestor: parentBox)
                : Offset.zero) &
            dividerBox.size,
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
