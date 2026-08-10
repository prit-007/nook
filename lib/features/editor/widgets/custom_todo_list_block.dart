import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/note_theme_scope.dart';

/// Re-skins the built-in `todo_list` block with a Material 3 checkbox and a
/// themed strikethrough for checked items.
class NookTodoListBlock {
  const NookTodoListBlock._();

  static const String type = TodoListBlockKeys.type;

  static const Key checkboxKey = Key('nook-todo-checkbox');

  static BlockComponentBuilder builder({
    BlockComponentConfiguration configuration =
        const BlockComponentConfiguration(),
  }) {
    return TodoListBlockComponentBuilder(
      configuration: configuration,
      textStyleBuilder: (checked) => checked
          ? const TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Color(0xFF9E9E9E),
            )
          : const TextStyle(),
      iconBuilder: (context, node, onCheck) =>
          _NookTodoCheckbox(node: node, onCheck: onCheck),
    );
  }
}

class _NookTodoCheckbox extends StatelessWidget {
  const _NookTodoCheckbox({required this.node, required this.onCheck});

  final Node node;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    final checked = node.attributes[TodoListBlockKeys.checked] ?? false;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCheck,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: AnimatedContainer(
          key: NookTodoListBlock.checkboxKey,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: checked ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: checked ? scheme.primary : scheme.outline,
              width: 1.8,
            ),
          ),
          child: checked
              ? Icon(Icons.check, size: 15, color: scheme.onPrimary)
              : null,
        ),
      ),
    );
  }
}
