import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/note_theme_scope.dart';

/// Attribute keys for the Callout block component.
class CalloutBlockKeys {
  const CalloutBlockKeys._();

  static const String type = 'callout';
  static const String icon = 'icon';
  static const String calloutType = 'callout_type';
}

/// Creates a Callout [Node] with custom icon, type, and text content.
Node calloutNode({
  String text = '',
  String icon = 'bulb',
  String calloutType = 'info',
}) {
  return Node(
    type: CalloutBlockKeys.type,
    attributes: {
      CalloutBlockKeys.icon: icon,
      CalloutBlockKeys.calloutType: calloutType,
      blockComponentDelta: (Delta()..insert(text)).toJson(),
    },
  );
}

/// Builder mapping callout nodes to [CalloutBlockComponentWidget].
class CalloutBlockComponentBuilder extends BlockComponentBuilder {
  CalloutBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CalloutBlockComponentWidget(
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

class CalloutBlockComponentWidget extends BlockComponentStatefulWidget {
  const CalloutBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<CalloutBlockComponentWidget> createState() =>
      _CalloutBlockComponentWidgetState();
}

class _CalloutBlockComponentWidgetState
    extends State<CalloutBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'callout_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: CalloutBlockKeys.type,
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
    final iconName =
        node.attributes[CalloutBlockKeys.icon] as String? ?? 'bulb';
    final textDir = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    Widget child = Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: scheme.primary,
            width: 4,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: HugeIcon(
              icon: switch (iconName) {
                'info' => HugeIcons.strokeRoundedInformationCircle,
                'warning' => HugeIcons.strokeRoundedAlertCircle,
                'note' => HugeIcons.strokeRoundedNote01,
                _ => HugeIcons.strokeRoundedBulb,
              },
              size: 20,
              color: scheme.primary,
            ),
          ),
          Expanded(
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorState: editorState,
              textAlign: alignment?.toTextAlign ?? textAlign,
              placeholderText: 'Callout note...',
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                textStyleWithTextSpan(textSpan: textSpan),
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
