import 'dart:async';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/note_theme_scope.dart';

/// Attribute keys for the Collapsible section block component.
class CollapsibleBlockKeys {
  const CollapsibleBlockKeys._();

  static const String type = 'collapsible';
  static const String collapsed = 'collapsed';
}

/// Creates a Collapsible section [Node].
Node collapsibleNode({
  String title = '',
  bool collapsed = false,
  Iterable<Node> children = const [],
}) {
  return Node(
    type: CollapsibleBlockKeys.type,
    attributes: {
      CollapsibleBlockKeys.collapsed: collapsed,
      blockComponentDelta: (Delta()..insert(title)).toJson(),
    },
    children: children,
  );
}

/// Builder mapping collapsible nodes to [CollapsibleBlockComponentWidget].
class CollapsibleBlockComponentBuilder extends BlockComponentBuilder {
  CollapsibleBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CollapsibleBlockComponentWidget(
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
  BlockComponentValidate get validate => (node) => node.delta != null;
}

class CollapsibleBlockComponentWidget extends BlockComponentStatefulWidget {
  const CollapsibleBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<CollapsibleBlockComponentWidget> createState() =>
      _CollapsibleBlockComponentWidgetState();
}

class _CollapsibleBlockComponentWidgetState
    extends State<CollapsibleBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'collapsible_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: CollapsibleBlockKeys.type,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  late final EditorState editorState =
      Provider.of<EditorState>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    final isCollapsed =
        node.attributes[CollapsibleBlockKeys.collapsed] as bool? ?? false;
    final textDir = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    Widget child = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  final transaction = editorState.transaction;
                  transaction.updateNode(node, {
                    CollapsibleBlockKeys.collapsed: !isCollapsed,
                  });
                  editorState.apply(transaction);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: HugeIcon(
                    icon: isCollapsed
                        ? HugeIcons.strokeRoundedArrowRight01
                        : HugeIcons.strokeRoundedArrowDown01,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: AppFlowyRichText(
                  key: forwardKey,
                  delegate: this,
                  node: widget.node,
                  editorState: editorState,
                  textAlign: alignment?.toTextAlign ?? textAlign,
                  placeholderText: 'Toggle section header...',
                  textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                    textStyleWithTextSpan(textSpan: textSpan).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  placeholderTextSpanDecorator: (textSpan) =>
                      textSpan.updateTextStyle(
                    placeholderTextStyleWithTextSpan(textSpan: textSpan),
                  ),
                  textDirection: textDir,
                  cursorColor: editorState.editorStyle.cursorColor,
                  selectionColor: editorState.editorStyle.selectionColor,
                  cursorWidth: editorState.editorStyle.cursorWidth,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    return child;
  }
}
