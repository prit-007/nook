import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import 'media_delete_button.dart';

/// Signature for a callback invoked when an image block's delete button is tapped.
typedef ImageBlockDeleteCallback = void Function(
  Node node,
  EditorState editorState,
);

/// An image block component that shows a full-screen zoomable viewer on tap.
///
/// Registers the built-in [ImageBlockComponentBuilder] and wraps the rendered
/// widget in a [GestureDetector] so tapping an image opens an
/// [InteractiveViewer] dialog.
class NookImageBlockComponentBuilder extends BlockComponentBuilder {
  NookImageBlockComponentBuilder({
    super.configuration,
    this.onDelete,
  });

  final ImageBlockDeleteCallback? onDelete;

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return NookImageBlockComponentWidget(
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
      onDelete: onDelete,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

/// Widget for an image block that opens a full-screen zoomable viewer on tap.
class NookImageBlockComponentWidget extends BlockComponentStatefulWidget {
  const NookImageBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.onDelete,
  });

  final ImageBlockDeleteCallback? onDelete;

  @override
  State<NookImageBlockComponentWidget> createState() =>
      _NookImageBlockComponentWidgetState();
}

class _NookImageBlockComponentWidgetState
    extends State<NookImageBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final _imageKey = GlobalKey();

  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  Widget build(BuildContext context) {
    final attributes = node.attributes;
    final src = attributes[ImageBlockKeys.url] as String? ?? '';
    final alignment = AlignmentExtension.fromString(
      attributes[ImageBlockKeys.align] ?? 'center',
    );
    final width = attributes[ImageBlockKeys.width]?.toDouble() ??
        MediaQuery.of(context).size.width;
    final height = attributes[ImageBlockKeys.height]?.toDouble();

    Widget child = Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _openZoomViewer(context, src),
          child: _buildImage(src, width, height, alignment),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: MediaDeleteButton(
            tooltip: 'Delete image',
            onPressed: () {
              final editorState = context.read<EditorState>();
              widget.onDelete?.call(node, editorState);
            },
          ),
        ),
      ],
    );

    child = Padding(
      key: _imageKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: context.read<EditorState>().selectionNotifier,
      remoteSelection: context.read<EditorState>().remoteSelections,
      blockColor: context.read<EditorState>().editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
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

  Widget _buildImage(
    String src,
    double width,
    double? height,
    Alignment alignment,
  ) {
    if (src.isEmpty) {
      return Container(
        height: 100,
        width: width,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedImage01,
          size: 36,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    Widget image;
    if (src.startsWith('http://') || src.startsWith('https://')) {
      image = Image.network(src,
          width: width, height: height, fit: BoxFit.fitWidth);
    } else {
      image = Image.file(File(src),
          width: width, height: height, fit: BoxFit.fitWidth);
    }

    return Align(alignment: alignment, child: image);
  }

  void _openZoomViewer(BuildContext context, String src) {
    if (src.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ZoomableImageViewer(src: src),
      ),
    );
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
    final box = _imageKey.currentContext?.findRenderObject();
    if (box is RenderBox) return Offset.zero & box.size;
    return Rect.zero;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) return null;
    final size = _renderBox!.size;
    return Rect.fromLTWH(-size.width / 2.0, 0, size.width, size.height);
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) return [];
    final parentBox = context.findRenderObject();
    final imageBox = _imageKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && imageBox is RenderBox) {
      return [
        imageBox.localToGlobal(Offset.zero, ancestor: parentBox) &
            imageBox.size,
      ];
    }
    return [Offset.zero & _renderBox!.size];
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

/// Full-screen viewer for an image with pinch-to-zoom and pan support.
class _ZoomableImageViewer extends StatelessWidget {
  const _ZoomableImageViewer({required this.src});

  final String src;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(child: _buildImage(src)),
      ),
    );
  }

  Widget _buildImage(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(src, fit: BoxFit.contain);
    } else {
      return Image.file(File(src), fit: BoxFit.contain);
    }
  }
}
