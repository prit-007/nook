import 'dart:async';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/note_theme_scope.dart';

/// Attribute keys for the Code block component.
class CodeBlockKeys {
  const CodeBlockKeys._();

  static const String type = 'code';
  static const String language = 'language';
}

/// Creates a Code [Node] with optional programming language and snippet text.
Node codeBlockNode({
  String code = '',
  String language = 'text',
}) {
  return Node(
    type: CodeBlockKeys.type,
    attributes: {
      CodeBlockKeys.language: language,
      blockComponentDelta: (Delta()..insert(code)).toJson(),
    },
  );
}

/// Builder mapping code nodes to [CodeBlockComponentWidget].
class CodeBlockComponentBuilder extends BlockComponentBuilder {
  CodeBlockComponentBuilder({super.configuration});

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CodeBlockComponentWidget(
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

class CodeBlockComponentWidget extends BlockComponentStatefulWidget {
  const CodeBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<CodeBlockComponentWidget> createState() =>
      _CodeBlockComponentWidgetState();
}

class _CodeBlockComponentWidgetState extends State<CodeBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'code_rich_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: CodeBlockKeys.type,
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
    final language =
        node.attributes[CodeBlockKeys.language] as String? ?? 'text';
    final textDir = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    Widget child = Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Language badge + copy code action
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy code',
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCopy01,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    unawaited(HapticFeedback.lightImpact());
                    final plainText = node.delta?.toPlainText() ?? '';
                    Clipboard.setData(ClipboardData(text: plainText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Code editor content
          Padding(
            padding: const EdgeInsets.all(14),
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorState: editorState,
              textAlign: alignment?.toTextAlign ?? textAlign,
              placeholderText: 'Enter code...',
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                  color: scheme.onSurface,
                ),
              ),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(
                TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
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
