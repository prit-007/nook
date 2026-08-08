import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Block keys for the doodle custom node.
class DoodleBlockKeys {
  const DoodleBlockKeys._();

  static const String type = 'doodle';
  static const String attachmentId = 'attachment_id';
  static const String thumbnailData = 'thumbnail_data';
}

/// Creates a doodle [Node] for embedding in the AppFlowy Editor.
Node doodleNode({
  required String attachmentId,
  String? thumbnailData,
}) {
  return Node(
    type: DoodleBlockKeys.type,
    attributes: {
      DoodleBlockKeys.attachmentId: attachmentId,
      if (thumbnailData != null) DoodleBlockKeys.thumbnailData: thumbnailData,
    },
  );
}

/// Builder that maps a doodle node to [DoodleBlockComponentWidget].
class DoodleBlockComponentBuilder extends BlockComponentBuilder {
  DoodleBlockComponentBuilder({
    super.configuration,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return DoodleBlockComponentWidget(
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
      onTap: onTap,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

/// Widget for an inline doodle block inside the editor.
class DoodleBlockComponentWidget extends BlockComponentStatefulWidget {
  const DoodleBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  State<DoodleBlockComponentWidget> createState() =>
      _DoodleBlockComponentWidgetState();
}

class _DoodleBlockComponentWidgetState extends State<DoodleBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final _doodleKey = GlobalKey();

  late final editorState = Provider.of<EditorState>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumbnailData = node.attributes[DoodleBlockKeys.thumbnailData];

    Widget child = GestureDetector(
      onTap: widget.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: thumbnailData != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  Uri.parse('data:image/png;base64,$thumbnailData')
                      .data!
                      .contentAsBytes(),
                  fit: BoxFit.contain,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.brush,
                    size: 48,
                    color: scheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to edit doodle',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
      ),
    );

    child = Padding(
      key: _doodleKey,
      padding: padding,
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

  // --- SelectableMixin overrides (non-text block pattern) ---

  @override
  Position start() => Position(path: node.path, offset: 0);

  @override
  Position end() => Position(path: node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final box = _doodleKey.currentContext?.findRenderObject();
    if (box is RenderBox) return Offset.zero & box.size;
    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    final parentBox = context.findRenderObject();
    final doodleBox = _doodleKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && doodleBox is RenderBox) {
      return doodleBox.localToGlobal(Offset.zero, ancestor: parentBox) &
          doodleBox.size;
    }
    return null;
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final parentBox = context.findRenderObject();
    final doodleBox = _doodleKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && doodleBox is RenderBox) {
      return [
        doodleBox.localToGlobal(Offset.zero, ancestor: parentBox) &
            doodleBox.size,
      ];
    }
    return [Rect.zero];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: node.path, startOffset: 0, endOffset: 1);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    final box = context.findRenderObject();
    if (box is RenderBox) return box.localToGlobal(offset);
    return Offset.zero;
  }
}
