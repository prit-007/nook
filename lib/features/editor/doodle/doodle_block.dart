import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/note_theme_scope.dart';
import '../widgets/media_delete_button.dart';

/// Block keys for the doodle custom node.
class DoodleBlockKeys {
  const DoodleBlockKeys._();

  static const String type = 'doodle';
  static const String attachmentId = 'attachment_id';
  static const String thumbnailPath = 'thumbnail_path';
  static const String aspectRatio = 'aspect_ratio';
  static const String backgroundTemplate = 'background_template';
}

/// Creates a doodle [Node] for embedding in the AppFlowy Editor.
///
/// The node stores only file references — no inline binary data.
/// Stroke data lives in the Attachments table sidecar file.
Node doodleNode({
  required String attachmentId,
  String? thumbnailPath,
  double aspectRatio = 1.333,
  String backgroundTemplate = 'dotted',
}) {
  return Node(
    type: DoodleBlockKeys.type,
    attributes: {
      DoodleBlockKeys.attachmentId: attachmentId,
      DoodleBlockKeys.thumbnailPath: thumbnailPath ?? '',
      DoodleBlockKeys.aspectRatio: aspectRatio,
      DoodleBlockKeys.backgroundTemplate: backgroundTemplate,
    },
  );
}

/// Signature for a callback invoked when a doodle block is tapped.
typedef DoodleBlockTapCallback = void Function(
  Node node,
  EditorState editorState,
);

/// Signature for a callback invoked when a doodle block's delete button is tapped.
typedef DoodleBlockDeleteCallback = void Function(
  Node node,
  EditorState editorState,
);

/// Builder that maps a doodle node to [DoodleBlockComponentWidget].
class DoodleBlockComponentBuilder extends BlockComponentBuilder {
  DoodleBlockComponentBuilder({
    super.configuration,
    this.onTap,
    this.onDelete,
  });

  final DoodleBlockTapCallback? onTap;
  final DoodleBlockDeleteCallback? onDelete;

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
      onDelete: onDelete,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta == null && node.children.isEmpty;
}

/// Widget for an inline doodle block inside the editor.
///
/// Renders the persisted thumbnail from the Attachments sidecar and, when
/// tapped, allows the owning [EditorState] to launch the full doodle canvas.
/// Thumbnail updates are persisted back to the editor document via a
/// [Transaction] so the inline doodle block stays in sync.
class DoodleBlockComponentWidget extends BlockComponentStatefulWidget {
  const DoodleBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
    this.onTap,
    this.onDelete,
  });

  final DoodleBlockTapCallback? onTap;
  final DoodleBlockDeleteCallback? onDelete;

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
    final scheme = NoteThemeScope.of(context);
    final thumbnailPath =
        node.attributes[DoodleBlockKeys.thumbnailPath] as String? ?? '';
    final aspectRatio =
        (node.attributes[DoodleBlockKeys.aspectRatio] as num?)?.toDouble() ??
            1.333;
    final backgroundTemplate =
        node.attributes[DoodleBlockKeys.backgroundTemplate] as String? ??
            'dotted';

    Widget visual;
    if (thumbnailPath.isNotEmpty && File(thumbnailPath).existsSync()) {
      visual = AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(thumbnailPath),
            fit: BoxFit.contain,
          ),
        ),
      );
    } else {
      visual = AspectRatio(
        aspectRatio: aspectRatio,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: DoodleBlockBackgroundIcons.fromTemplate(backgroundTemplate),
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
      );
    }

    Widget child = Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => widget.onTap?.call(node, editorState),
          child: Container(
            constraints: const BoxConstraints(minHeight: 120),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: visual,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: MediaDeleteButton(
            tooltip: 'Delete doodle',
            onPressed: () => widget.onDelete?.call(node, editorState),
          ),
        ),
      ],
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

/// Maps a background template name to an icon for the inline placeholder.
class DoodleBlockBackgroundIcons {
  const DoodleBlockBackgroundIcons._();

  static List<List<dynamic>> fromTemplate(String template) {
    switch (template) {
      case 'blank':
        return HugeIcons.strokeRoundedFile01;
      case 'ruled':
        return HugeIcons.strokeRoundedBookOpen01;
      case 'graph':
        return HugeIcons.strokeRoundedGrid;
      case 'dotted':
      default:
        return HugeIcons.strokeRoundedBrush;
    }
  }
}
