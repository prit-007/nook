import 'dart:async';
import 'package:appflowy_editor/appflowy_editor.dart'
    hide tableMenuItem, dividerMenuItem;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../data/repositories/note_link_repository.dart';
import 'widgets/callout_block.dart';
import 'widgets/code_block.dart';
import 'widgets/collapsible_block.dart';
import 'widgets/divider_block.dart';
import 'widgets/table_block.dart';

/// Markdown character shortcut converting '[[' to a note link trigger.
CharacterShortcutEvent formatDoubleBracketToNoteLink({
  required void Function(EditorState editorState) onTriggerNoteLink,
}) {
  return CharacterShortcutEvent(
    key: 'format double bracket to note link',
    character: '[',
    handler: (editorState) async {
      final selection = editorState.selection;
      if (selection == null || !selection.isCollapsed) return false;
      final node = editorState.getNodeAtPath(selection.start.path);
      if (node == null) return false;
      final text = node.delta?.toPlainText() ?? '';
      final offset = selection.start.offset;
      if (offset > 0 && offset <= text.length) {
        final prevChar = text[offset - 1];
        if (prevChar == '[') {
          onTriggerNoteLink(editorState);
          return true;
        }
      }
      return false;
    },
  );
}

/// Inserts a link to [noteId] with [title] at the current cursor selection,
/// optionally replacing a preceding prefix (e.g. '[' or '[[').
void insertNoteLinkAtSelection(
  EditorState editorState, {
  required String noteId,
  required String title,
  int deletePrefixLength = 0,
}) {
  final selection = editorState.selection;
  final pos = selection?.start ?? Position(path: const [0], offset: 0);
  final node = editorState.getNodeAtPath(pos.path);
  if (node == null) return;

  final label = title.trim().isEmpty ? 'Untitled' : title.trim();
  final offset = (pos.offset - deletePrefixLength).clamp(0, 1000000000);
  final transaction = editorState.transaction;
  transaction.replaceText(
    node,
    offset,
    deletePrefixLength,
    label,
    attributes: {
      AppFlowyRichTextKeys.href: noteLinkUri(noteId),
    },
  );
  editorState.apply(transaction);
}

/// Markdown character shortcut converting '> ' to a quote block.
final CharacterShortcutEvent formatGreaterThanToQuote = CharacterShortcutEvent(
  key: 'format greater than to quote',
  character: ' ',
  handler: (editorState) async => await formatMarkdownSymbol(
    editorState,
    (node) => node.type == ParagraphBlockKeys.type,
    (_, text, selection) => text == '>',
    (text, node, delta) => [
      quoteNode(
        delta: delta.compose(Delta()..delete(1)),
      ),
      if (node.children.isNotEmpty) ...node.children,
    ],
  ),
);

/// Markdown character shortcut converting '[ ] ' or '-[ ] ' to an unchecked checkbox.
final CharacterShortcutEvent formatBracketSpaceToUncheckedBox =
    CharacterShortcutEvent(
  key: 'format bracket space to unchecked box',
  character: ' ',
  handler: (editorState) async => await formatMarkdownSymbol(
    editorState,
    (node) => node.type == ParagraphBlockKeys.type,
    (_, text, selection) => text == '[ ]' || text == '-[ ]',
    (text, node, delta) {
      final deleteLen = text.length;
      return [
        todoListNode(
          checked: false,
          delta: delta.compose(Delta()..delete(deleteLen)),
        ),
        if (node.children.isNotEmpty) ...node.children,
      ];
    },
  ),
);

/// Markdown character shortcut converting '``` ' to a code block.
final CharacterShortcutEvent formatBackquotesToCodeBlock =
    CharacterShortcutEvent(
  key: 'format backquotes to code block',
  character: ' ',
  handler: (editorState) async => await formatMarkdownSymbol(
    editorState,
    (node) => node.type == ParagraphBlockKeys.type,
    (_, text, selection) => text == '```',
    (text, node, delta) => [
      codeBlockNode(),
      if (node.children.isNotEmpty) ...node.children,
    ],
  ),
);

/// Builds the curated selection menu items for Nook's '/' slash command.
List<SelectionMenuItem> buildNookSlashMenuItems({
  required VoidCallback onInsertDoodle,
  VoidCallback? onInsertNoteLink,
  VoidCallback? onInsertImage,
  VoidCallback? onScanOcr,
  VoidCallback? onDictateVoice,
}) {
  return [
    SelectionMenuItem(
      getName: () => 'Text',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'text',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['text', 'paragraph'],
      handler: (editorState, _, __) {
        insertNodeAfterSelection(editorState, paragraphNode());
      },
    ),
    SelectionMenuItem(
      getName: () => 'Heading 1',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'h1',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['heading 1', 'h1'],
      handler: (editorState, _, __) {
        insertHeadingAfterSelection(editorState, 1);
      },
    ),
    SelectionMenuItem(
      getName: () => 'Heading 2',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'h2',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['heading 2', 'h2'],
      handler: (editorState, _, __) {
        insertHeadingAfterSelection(editorState, 2);
      },
    ),
    SelectionMenuItem(
      getName: () => 'Heading 3',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'h3',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['heading 3', 'h3'],
      handler: (editorState, _, __) {
        insertHeadingAfterSelection(editorState, 3);
      },
    ),
    SelectionMenuItem(
      getName: () => 'Bulleted list',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'bulleted_list',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['bulleted list', 'list', 'bullet'],
      handler: (editorState, _, __) {
        insertBulletedListAfterSelection(editorState);
      },
    ),
    SelectionMenuItem(
      getName: () => 'Numbered list',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'number',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['numbered list', 'list', 'number'],
      handler: (editorState, _, __) {
        insertNumberedListAfterSelection(editorState);
      },
    ),
    SelectionMenuItem(
      getName: () => 'Checkbox',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'checkbox',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['checkbox', 'todo', 'task'],
      handler: (editorState, _, __) {
        insertCheckboxAfterSelection(editorState);
      },
    ),
    SelectionMenuItem(
      getName: () => 'Quote',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'quote',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['quote', 'blockquote'],
      handler: (editorState, _, __) {
        insertQuoteAfterSelection(editorState);
      },
    ),
    SelectionMenuItem(
      getName: () => 'Callout',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'quote',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['callout', 'info', 'tip', 'note', 'alert'],
      handler: (editorState, _, __) {
        insertNodeAfterSelection(editorState, calloutNode());
      },
    ),
    SelectionMenuItem(
      getName: () => 'Code block',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'text',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['code', 'code block', 'snippet', 'syntax'],
      handler: (editorState, _, __) {
        insertNodeAfterSelection(editorState, codeBlockNode());
      },
    ),
    SelectionMenuItem(
      getName: () => 'Collapsible section',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'bulleted_list',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['collapsible', 'toggle', 'accordion', 'details'],
      handler: (editorState, _, __) {
        insertNodeAfterSelection(editorState, collapsibleNode());
      },
    ),
    tableMenuItem,
    dividerMenuItem,
    SelectionMenuItem(
      getName: () => 'Image',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'image',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['image', 'photo', 'picture'],
      handler: (editorState, _, __) {
        onInsertImage?.call();
      },
    ),
    SelectionMenuItem(
      getName: () => 'Doodle',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'draw',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['doodle', 'draw', 'sketch'],
      handler: (editorState, _, __) {
        onInsertDoodle();
      },
    ),
    SelectionMenuItem(
      getName: () => 'Link to note',
      icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
        name: 'link',
        isSelected: isSelected,
        style: style,
      ),
      keywords: ['link', 'note', 'backlink', 'reference'],
      handler: (editorState, _, __) {
        onInsertNoteLink?.call();
      },
    ),
    if (onScanOcr != null)
      SelectionMenuItem(
        getName: () => 'Scan text (OCR)',
        icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
          name: 'image',
          isSelected: isSelected,
          style: style,
        ),
        keywords: ['ocr', 'scan', 'text', 'image', 'receipt'],
        handler: (editorState, _, __) {
          onScanOcr();
        },
      ),
    if (onDictateVoice != null)
      SelectionMenuItem(
        getName: () => 'Voice dictation',
        icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
          name: 'text',
          isSelected: isSelected,
          style: style,
        ),
        keywords: ['voice', 'mic', 'dictate', 'speech'],
        handler: (editorState, _, __) {
          onDictateVoice();
        },
      ),
  ];
}

/// Builds the toolbar items for the desktop floating selection toolbar.
List<ToolbarItem> buildDesktopFloatingToolbarItems() {
  return [
    ...headingItems,
    ...markdownFormatItems,
    linkItem,
    buildTextColorItem(),
    buildHighlightColorItem(),
    quoteItem,
    bulletedListItem,
    numberedListItem,
  ];
}

/// Grid menu shown by the mobile toolbar's custom blocks item.
class NookBlocksMenu extends StatefulWidget {
  const NookBlocksMenu({
    super.key,
    required this.editorState,
    required this.selection,
  });

  final EditorState editorState;
  final Selection selection;

  @override
  State<NookBlocksMenu> createState() => NookBlocksMenuState();
}

class NookBlocksMenuState extends State<NookBlocksMenu> {
  static const _items = [
    (
      icon: AFMobileIcons.h1,
      label: 'Heading 1',
      type: HeadingBlockKeys.type,
      level: 1,
    ),
    (
      icon: AFMobileIcons.h2,
      label: 'Heading 2',
      type: HeadingBlockKeys.type,
      level: 2,
    ),
    (
      icon: AFMobileIcons.h3,
      label: 'Heading 3',
      type: HeadingBlockKeys.type,
      level: 3,
    ),
    (
      icon: AFMobileIcons.bulletedList,
      label: 'Bulleted list',
      type: BulletedListBlockKeys.type,
      level: null,
    ),
    (
      icon: AFMobileIcons.numberedList,
      label: 'Numbered list',
      type: NumberedListBlockKeys.type,
      level: null,
    ),
    (
      icon: AFMobileIcons.checkbox,
      label: 'Checkbox',
      type: TodoListBlockKeys.type,
      level: null,
    ),
    (
      icon: AFMobileIcons.quote,
      label: 'Quote',
      type: QuoteBlockKeys.type,
      level: null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = MobileToolbarTheme.of(context);

    final children = _items.map((item) {
      final node =
          widget.editorState.getNodeAtPath(widget.selection.start.path);
      final isSelected = node?.type == item.type &&
          (item.level == null ||
              node?.attributes[HeadingBlockKeys.level] == item.level);

      return MobileToolbarItemMenuBtn(
        icon: AFMobileIcon(
          afMobileIcons: item.icon,
          color: MobileToolbarTheme.of(context).iconColor,
        ),
        label: Text(item.label),
        isSelected: isSelected,
        onPressed: () {
          setState(() {
            widget.editorState.formatNode(
              widget.selection,
              (n) => n.copyWith(
                type: isSelected ? ParagraphBlockKeys.type : item.type,
                attributes: {
                  ParagraphBlockKeys.delta: (n.delta ?? Delta()).toJson(),
                  blockComponentBackgroundColor:
                      n.attributes[blockComponentBackgroundColor],
                  if (!isSelected && item.type == TodoListBlockKeys.type)
                    TodoListBlockKeys.checked: false,
                  if (!isSelected && item.type == HeadingBlockKeys.type)
                    HeadingBlockKeys.level: item.level,
                },
              ),
              selectionExtraInfo: {
                selectionExtraInfoDoNotAttachTextService: true,
              },
            );
          });
        },
      );
    }).toList();

    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: buildMobileToolbarMenuGridDelegate(
        mobileToolbarStyle: style,
        crossAxisCount: 2,
      ),
      children: children,
    );
  }
}

/// Builds the mobile toolbar items shown above the on-screen keyboard.
///
/// Features a horizontally scrollable strip containing block type conversions,
/// text formatting, colors, checklist insertion, media shortcuts, and undo/redo.
List<MobileToolbarItem> buildMobileToolbarItems({
  required BuildContext context,
  required EditorState editorState,
  required VoidCallback onInsertDoodle,
  VoidCallback? onInsertImage,
  VoidCallback? onInsertNoteLink,
  VoidCallback? onUndo,
  VoidCallback? onRedo,
}) {
  return [
    // 1. Block menu (Headings, Lists, Checkbox, Quote)
    MobileToolbarItem.withMenu(
      itemIconBuilder: (context, editorState, _) => AFMobileIcon(
        afMobileIcons: AFMobileIcons.list,
        color: MobileToolbarTheme.of(context).iconColor,
      ),
      itemMenuBuilder: (context, editorState, _) {
        final selection = editorState.selection;
        if (selection == null) return const SizedBox.shrink();
        return NookBlocksMenu(
          editorState: editorState,
          selection: selection,
        );
      },
    ),
    // 2. Text styling menu (Bold, Italic, Strikethrough, Underline, Code)
    textDecorationMobileToolbarItemV2,
    // 3. Text and background color picker
    buildTextAndBackgroundColorMobileToolbarItem(),
    // 4. Quick Checkbox block insert/toggle
    todoListMobileToolbarItem,
    // 5. Note Hyperlink / URL picker
    linkMobileToolbarItem,
    // 6. Doodle canvas action
    MobileToolbarItem.action(
      itemIconBuilder: (context, editorState, _) => HugeIcon(
        icon: HugeIcons.strokeRoundedPenTool01,
        size: 20,
        color: MobileToolbarTheme.of(context).iconColor,
      ),
      actionHandler: (context, editorState) {
        unawaited(Future<void>.microtask(onInsertDoodle));
      },
    ),
    // 7. Horizontal Divider
    dividerMobileToolbarItem,
    // 8. Quick Undo
    MobileToolbarItem.action(
      itemIconBuilder: (context, editorState, _) => HugeIcon(
        icon: HugeIcons.strokeRoundedUndo02,
        size: 20,
        color: editorState.undoManager.undoStack.isNonEmpty
            ? MobileToolbarTheme.of(context).iconColor
            : MobileToolbarTheme.of(context).iconColor.withValues(alpha: 0.35),
      ),
      actionHandler: (context, editorState) {
        if (onUndo != null) {
          onUndo();
        } else if (editorState.undoManager.undoStack.isNonEmpty) {
          editorState.undoManager.undo();
        }
      },
    ),
    // 9. Quick Redo
    MobileToolbarItem.action(
      itemIconBuilder: (context, editorState, _) => HugeIcon(
        icon: HugeIcons.strokeRoundedRedo02,
        size: 20,
        color: editorState.undoManager.redoStack.isNonEmpty
            ? MobileToolbarTheme.of(context).iconColor
            : MobileToolbarTheme.of(context).iconColor.withValues(alpha: 0.35),
      ),
      actionHandler: (context, editorState) {
        if (onRedo != null) {
          onRedo();
        } else if (editorState.undoManager.redoStack.isNonEmpty) {
          editorState.undoManager.redo();
        }
      },
    ),
  ];
}
