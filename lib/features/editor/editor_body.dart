import 'dart:async';
import 'package:appflowy_editor/appflowy_editor.dart'
    hide DividerBlockComponentBuilder, TableBlockComponentBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../data/database.dart';
import '../../data/tables/notes.dart';
import 'checklist_editor.dart';
import 'doodle/doodle_block.dart';
import 'editor_toolbar.dart';
import 'widgets/callout_block.dart';
import 'widgets/code_block.dart';
import 'widgets/collapsible_block.dart';
import 'widgets/custom_todo_list_block.dart';
import 'widgets/divider_block.dart';
import 'widgets/paper_background.dart';
import 'widgets/table_block.dart';
import 'widgets/wiki_link_autocomplete.dart';
import 'widgets/zoomable_image_block.dart';

export 'widgets/paper_background.dart' show NotePaperStyle;

/// Inserts [node] into the editor document.
///
/// Uses the current collapsed selection when available; otherwise appends
/// after the last block. Returns the live in-tree [Node] so callers can
/// reference it for later [Transaction.updateNode] calls.
Node insertBlockNode(EditorState editorState, Node node) {
  final selection = editorState.selection;
  Path? insertPath;

  if (selection != null && selection.isCollapsed) {
    final success = insertNodeAfterSelection(editorState, node);
    if (success) {
      final pos = editorState.selection?.end.path;
      if (pos != null) {
        final live = editorState.getNodeAtPath(pos);
        if (live != null) return live;
      }
    }
  }

  final root = editorState.document.root;
  final last = root.children.lastOrNull;
  insertPath = last == null ? const [0] : last.path.next;

  final transaction = editorState.transaction;
  transaction
    ..insertNode(insertPath, node)
    ..afterSelection = Selection.collapsed(Position(path: insertPath));
  editorState.apply(transaction);

  return editorState.getNodeAtPath(insertPath) ?? node;
}

/// The main content body of the note editor.
///
/// Handles checklist notes vs standard node document notes, paper background
/// texture painting, mobile vs desktop editor presentation, markdown shortcuts,
/// curated slash command menu, and desktop floating selection toolbar.
class EditorBody extends StatefulWidget {
  const EditorBody({
    super.key,
    required this.editorState,
    required this.note,
    required this.noteScheme,
    required this.dynamicTextTheme,
    required this.paperStyle,
    required this.onInsertDoodle,
    this.readOnly = false,
    this.hasDoodleBlock = false,
    this.onInsertImage,
    this.onInsertNoteLink,
    this.onScanOcr,
    this.onDictateVoice,
    this.onOpenDoodleCanvas,
    this.onDeleteMediaBlock,
    this.checklistAttachments = const [],
    this.checklistTitle = '',
    this.onUpdateChecklistTitle,
    this.onInsertChecklistImage,
    this.onInsertChecklistDoodle,
    this.onOpenChecklistAttachment,
    this.onDeleteChecklistAttachment,
  });

  final EditorState editorState;
  final Note? note;
  final ColorScheme noteScheme;
  final TextTheme dynamicTextTheme;
  final NotePaperStyle paperStyle;
  final bool readOnly;
  final bool hasDoodleBlock;
  final VoidCallback onInsertDoodle;
  final VoidCallback? onInsertImage;
  final VoidCallback? onInsertNoteLink;
  final VoidCallback? onScanOcr;
  final VoidCallback? onDictateVoice;
  final void Function(Node node, EditorState state)? onOpenDoodleCanvas;
  final void Function(Node node, EditorState state)? onDeleteMediaBlock;

  final List<Attachment> checklistAttachments;
  final String checklistTitle;
  final ValueChanged<String>? onUpdateChecklistTitle;
  final Future<void> Function()? onInsertChecklistImage;
  final Future<void> Function()? onInsertChecklistDoodle;
  final Future<void> Function(Attachment)? onOpenChecklistAttachment;
  final Future<void> Function(Attachment)? onDeleteChecklistAttachment;

  @override
  State<EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<EditorBody> {
  late EditorScrollController _editorScrollController;

  @override
  void initState() {
    super.initState();
    _editorScrollController = EditorScrollController(
      editorState: widget.editorState,
      shrinkWrap: false,
    );
  }

  @override
  void didUpdateWidget(covariant EditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editorState != widget.editorState) {
      _editorScrollController.dispose();
      _editorScrollController = EditorScrollController(
        editorState: widget.editorState,
        shrinkWrap: false,
      );
    }
  }

  @override
  void dispose() {
    _editorScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: widget.paperStyle != NotePaperStyle.blank
          ? PaperBackgroundPainter(
              style: widget.paperStyle,
              color: widget.noteScheme.onSurface.withValues(alpha: 0.06),
            )
          : null,
      child: widget.note?.type == NoteType.checklist
          ? ChecklistEditor(
              noteId: widget.note!.id,
              title: widget.checklistTitle,
              initialAttachments: widget.checklistAttachments,
              onTitleChanged: widget.onUpdateChecklistTitle ?? (_) {},
              onInsertImage: widget.onInsertChecklistImage,
              onInsertDoodle: widget.onInsertChecklistDoodle,
              onOpenAttachment: widget.onOpenChecklistAttachment,
              onDeleteAttachment: widget.onDeleteChecklistAttachment,
            )
          : _buildDocumentEditor(context),
    );
  }

  Widget _buildDocumentEditor(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    final editor = AppFlowyEditor(
      editorState: widget.editorState,
      editorScrollController: _editorScrollController,
      editorStyle: isMobile
          ? EditorStyle.mobile(
              cursorColor: widget.noteScheme.primary,
              selectionColor: widget.noteScheme.primary.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyleConfiguration: TextStyleConfiguration(
                text: widget.dynamicTextTheme.bodyLarge!.copyWith(
                  color: widget.noteScheme.onSurface,
                  height: 1.65,
                ),
              ),
            )
          : EditorStyle.desktop(
              cursorColor: widget.noteScheme.primary,
              selectionColor: widget.noteScheme.primary.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyleConfiguration: TextStyleConfiguration(
                text: widget.dynamicTextTheme.bodyLarge!.copyWith(
                  color: widget.noteScheme.onSurface,
                  height: 1.65,
                ),
              ),
            ),
      editable: !widget.readOnly,
      autoFocus: !widget.readOnly,
      blockComponentBuilders: {
        ...standardBlockComponentBuilderMap,
        TodoListBlockKeys.type: NookTodoListBlock.builder(),
        DoodleBlockKeys.type: DoodleBlockComponentBuilder(
          configuration: BlockComponentConfiguration(
            padding: (_) => const EdgeInsets.symmetric(vertical: 24),
          ),
          onTap: (node, state) {
            HapticFeedback.lightImpact();
            widget.onOpenDoodleCanvas?.call(node, state);
          },
          onDelete: widget.onDeleteMediaBlock,
        ),
        ImageBlockKeys.type: NookImageBlockComponentBuilder(
          onDelete: widget.onDeleteMediaBlock,
        ),
        CalloutBlockKeys.type: CalloutBlockComponentBuilder(),
        CodeBlockKeys.type: CodeBlockComponentBuilder(),
        CollapsibleBlockKeys.type: CollapsibleBlockComponentBuilder(),
        DividerBlockKeys.type: DividerBlockComponentBuilder(),
        TableBlockKeys.type: TableBlockComponentBuilder(),
      },
      characterShortcutEvents: [
        ...standardCharacterShortcutEvents,
        formatGreaterThanToQuote,
        formatBracketSpaceToUncheckedBox,
        formatBackquotesToCodeBlock,
        customSlashCommand(
          buildNookSlashMenuItems(
            onInsertDoodle: widget.onInsertDoodle,
            onInsertNoteLink: widget.onInsertNoteLink,
            onInsertImage: widget.onInsertImage,
            onScanOcr: widget.onScanOcr,
            onDictateVoice: widget.onDictateVoice,
          ),
        ),
      ],
    );

    final editorWithWikiAutocomplete = WikiLinkAutocomplete(
      editorState: widget.editorState,
      currentNoteId: widget.note?.id,
      readOnly: widget.readOnly,
      onBrowseAll: widget.onInsertNoteLink,
      child: editor,
    );

    final showDoodlePrompt =
        widget.note?.type == NoteType.doodle && !widget.hasDoodleBlock;

    if (isMobile) {
      final childWidget = showDoodlePrompt
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDoodlePromptCard(),
                Expanded(child: editorWithWikiAutocomplete),
              ],
            )
          : editorWithWikiAutocomplete;

      return MobileToolbarV2(
        editorState: widget.editorState,
        backgroundColor:
            widget.noteScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        foregroundColor: widget.noteScheme.onSurface,
        iconColor: widget.noteScheme.onSurface,
        itemHighlightColor: widget.noteScheme.primary,
        primaryColor: widget.noteScheme.primary,
        onPrimaryColor: widget.noteScheme.onPrimary,
        itemOutlineColor:
            widget.noteScheme.outlineVariant.withValues(alpha: 0.4),
        toolbarItems: buildMobileToolbarItems(
          context: context,
          editorState: widget.editorState,
          onInsertDoodle: widget.onInsertDoodle,
          onInsertImage: widget.onInsertImage,
          onInsertNoteLink: widget.onInsertNoteLink,
        ),
        child: childWidget,
      );
    }

    final desktopBody = FloatingToolbar(
      items: buildDesktopFloatingToolbarItems(),
      style: FloatingToolbarStyle(
        backgroundColor: widget.noteScheme.surfaceContainerHighest,
        toolbarActiveColor: widget.noteScheme.primary,
        toolbarIconColor: widget.noteScheme.onSurface,
        toolbarShadowColor: widget.noteScheme.shadow.withValues(alpha: 0.15),
        toolbarElevation: 4,
      ),
      editorState: widget.editorState,
      editorScrollController: _editorScrollController,
      textDirection: TextDirection.ltr,
      child: editorWithWikiAutocomplete,
    );

    if (showDoodlePrompt) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDoodlePromptCard(),
          Expanded(child: desktopBody),
        ],
      );
    }

    return desktopBody;
  }

  Widget _buildDoodlePromptCard() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        unawaited(Future<void>.microtask(widget.onInsertDoodle));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: widget.noteScheme.primaryContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.noteScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.noteScheme.primary.withValues(alpha: 0.15),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedDrawingMode,
                  size: 24,
                  color: widget.noteScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a drawing to this note',
              style: widget.dynamicTextTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: widget.noteScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to open the drawing canvas',
              style: widget.dynamicTextTheme.bodySmall?.copyWith(
                color: widget.noteScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
