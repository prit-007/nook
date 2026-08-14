import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/talker_provider.dart';
import '../../core/theme/note_theme.dart';
import '../../core/theme/note_theme_scope.dart';
import '../../data/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/checklist_item_repository.dart';
import '../../data/repositories/doodle_storage.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';
import '../../data/tables/attachments.dart';
import '../../features/doodle/doodle_canvas_screen.dart';
import '../../features/doodle/doodle_thumbnail_renderer.dart';
import 'doodle/doodle_block.dart';
import 'note_exporter.dart';
import 'widgets/custom_todo_list_block.dart';
import 'widgets/image_picker_handler.dart';
import 'widgets/note_options_sheet.dart';
import 'widgets/zoomable_image_block.dart';
import 'checklist_editor.dart';

/// Inserts [node] into the editor document.
///
/// Uses the current collapsed selection when available; otherwise appends
/// after the last block.  Returns the live in-tree [Node] so callers can
/// reference it for later [Transaction.updateNode] calls.
Node insertBlockNode(EditorState editorState, Node node) {
  final selection = editorState.selection;
  Path? insertPath;

  if (selection != null && selection.isCollapsed) {
    final success = insertNodeAfterSelection(editorState, node);
    if (success) {
      // insertNodeAfterSelection deep-copies; re-fetch the live node.
      final pos = editorState.selection?.end.path;
      if (pos != null) {
        final live = editorState.getNodeAtPath(pos);
        if (live != null) return live;
      }
    }
  }

  // No valid selection — append after the last block.
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

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.notebookId,
    this.type,
  });

  final String? noteId;
  final String? notebookId;
  final String? type;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  EditorState? _editorState;
  Note? _note;
  String _title = '';
  bool _pinned = false;
  bool _locked = false;
  bool _loading = true;
  bool _saving = false;
  bool _saveQueued = false;
  bool _disposed = false;
  String? _colorSeed;
  String? _notebookId;
  Timer? _autosaveTimer;
  StreamSubscription<void>? _transactionSubscription;
  AppDatabase? _db;
  bool _corruptedDelta = false;

  /// Tracks whether the user has made real edits since the last save.
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _db = ref.read(databaseProvider);
    final repo = NoteRepository(_db!);

    if (widget.noteId != null) {
      final note = await repo.getNoteById(widget.noteId!);
      if (_disposed || !mounted) return;
      if (note == null) {
        context.pop();
        return;
      }
      _note = note;
      _title = note.title;
      _pinned = note.pinned;
      _locked = note.locked;
      _colorSeed = note.colorSeed;
      _notebookId = note.notebookId;

      // Biometric re-prompt for locked notes.
      if (note.locked) {
        final auth = LocalAuthentication();
        try {
          final ok = await auth.authenticate(
            localizedReason: 'This note is locked',
            biometricOnly: true,
            persistAcrossBackgrounding: true,
          );
          if (_disposed || !mounted) {
            _cleanupInit();
            return;
          }
          if (!ok) {
            context.pop();
            return;
          }
        } catch (_) {
          if (!_disposed && mounted) context.pop();
          _cleanupInit();
          return;
        }
      }

      if (note.deltaContent != null && note.deltaContent!.isNotEmpty) {
        try {
          final json =
              Map<String, dynamic>.from(jsonDecode(note.deltaContent!) as Map);
          final document = Document.fromJson(json);
          _editorState = EditorState(document: document);
        } catch (e) {
          _editorState = EditorState.blank(withInitialText: true);
          _corruptedDelta = true;
        }
      } else {
        _editorState = EditorState.blank(withInitialText: true);
        if (note.title.isNotEmpty) {
          final transaction = _editorState!.transaction;
          final nodes = _editorState!.document.root.children;
          if (nodes.isNotEmpty) {
            final firstNode = nodes.first;
            if (firstNode.delta != null && firstNode.delta!.isEmpty) {
              transaction.insertText(firstNode, 0, note.title);
              await _editorState!.apply(transaction);
            }
          }
        }
      }
    } else {
      final noteType = NoteType.values.firstWhere(
        (t) => t.name == widget.type,
        orElse: () => NoteType.text,
      );
      final note = await repo.createNote(
        title: '',
        type: noteType,
        deviceOriginId: 'local',
        notebookId: widget.notebookId,
      );
      if (_disposed || !mounted) {
        // Clean up the blank note we just created.
        await repo.permanentlyDelete(note.id);
        _cleanupInit();
        return;
      }
      _note = note;
      _editorState = EditorState.blank(withInitialText: true);
    }

    if (_disposed || !mounted) {
      _cleanupInit();
      return;
    }

    _transactionSubscription = _editorState!.transactionStream.listen((_) {
      _dirty = true;
      _scheduleAutosave();
    });

    setState(() => _loading = false);
    if (widget.noteId == null && _note?.type == NoteType.doodle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_insertDoodle());
      });
    }
    if (_corruptedDelta) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Note content was corrupted. A fresh note was started.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  /// Cleans up resources if _init() completes after disposal.
  void _cleanupInit() {
    _editorState?.dispose();
    _editorState = null;
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 600), _save);
    nookLog(NookLogKey.editor, 'Autosave triggered for ${_note?.id}',
        LogLevel.debug);
  }

  Future<void> _save() async {
    if (_disposed || _note == null || _editorState == null) return;
    if (!_dirty) return;
    if (_saving) {
      _saveQueued = true;
      return;
    }

    _saving = true;
    try {
      final repo = NoteRepository(_db!);

      final nodes = _editorState!.document.root.children;
      String plainText = '';
      for (final node in nodes) {
        if (node.delta != null) {
          for (final op in node.delta!.toList()) {
            if (op is TextInsert) {
              plainText += op.text;
            }
          }
          plainText += '\n';
        }
      }
      plainText = plainText.trim();

      final derivedTitle = plainText.split('\n').firstOrNull ?? _title;
      if (derivedTitle != _title && derivedTitle.isNotEmpty) {
        await repo.updateNote(_note!.id, title: derivedTitle);
        _title = derivedTitle;
      }

      final deltaJson = jsonEncode(_editorState!.document.toJson());
      await repo.updateContent(
        _note!.id,
        deltaContent: deltaJson,
        plainText: plainText,
      );

      // Keep the local note mirror fresh so the app bar timestamp and the
      // export path always reflect the latest state.
      final now = DateTime.now();
      _note = _note!.copyWith(
        title: derivedTitle.isNotEmpty ? derivedTitle : _title,
        deltaContent: Value(deltaJson),
        plainText: Value(plainText),
        updatedAt: now,
      );

      // Update snapshot after successful save.
      _dirty = false;
      nookLog(
        NookLogKey.editor,
        'Note saved: ${_note!.id} (${plainText.length} chars)',
        LogLevel.info,
      );
    } finally {
      _saving = false;
      if (!_disposed && _saveQueued) {
        _saveQueued = false;
        unawaited(_save());
      }
    }
  }

  Future<void> _togglePin() async {
    if (_note == null) return;
    unawaited(HapticFeedback.lightImpact());
    final repo = NoteRepository(_db!);
    final newPinned = !_pinned;
    setState(() => _pinned = newPinned);
    await repo.updateNote(_note!.id, pinned: newPinned);
  }

  Future<void> _showNoteOptions() async {
    if (_note == null) return;
    // ignore: unawaited_futures
    HapticFeedback.selectionClick();
    final repo = NoteRepository(_db!);

    await NoteOptionsSheet.show(
      context,
      noteId: _note!.id,
      currentNotebookId: _notebookId,
      currentColorSeed: _colorSeed,
      currentlyLocked: _locked,
      onNotebookChanged: (id) async {
        _notebookId = id;
        await repo.updateNote(_note!.id, notebookId: id);
      },
      onColorChanged: (color) async {
        setState(() => _colorSeed = color);
        await repo.updateNote(_note!.id, colorSeed: color);
      },
      onTagsChanged: (tagIds) async {
        await repo.updateNoteTags(_note!.id, tagIds);
      },
      onLockedChanged: (locked) async {
        if (locked) {
          // Require biometric before locking.
          final auth = LocalAuthentication();
          try {
            final ok = await auth.authenticate(
              localizedReason: 'Authenticate to lock this note',
              biometricOnly: true,
              persistAcrossBackgrounding: true,
            );
            if (!ok) return;
          } catch (_) {
            return;
          }
        }
        setState(() => _locked = locked);
        await repo.updateNote(_note!.id, locked: locked);
      },
    );
  }

  /// Picks an image and inserts it into the editor at the current cursor.
  Future<void> _insertImage() async {
    if (_note == null || _editorState == null) return;
    unawaited(HapticFeedback.lightImpact());

    final baseDir = await getApplicationDocumentsDirectory();
    final handler = ImagePickerHandler(
      attachments: AttachmentRepository(_db!),
      baseDir: baseDir,
    );

    final result = await handler.pickAndStore(noteId: _note!.id);
    if (result == null || !mounted) return;

    // Insert an image node at the current cursor position (or after last block).
    final node = imageNode(url: result.filePath);
    insertBlockNode(_editorState!, node);

    // Force an empty paragraph after the image so the user can keep typing.
    final pNode = paragraphNode();
    insertBlockNode(_editorState!, pNode);

    _dirty = true;
    _scheduleAutosave();
  }

  /// Picks an image and stores it as a checklist attachment.
  Future<void> _insertChecklistImage() async {
    if (_note == null) return;
    unawaited(HapticFeedback.lightImpact());

    final baseDir = await getApplicationDocumentsDirectory();
    final handler = ImagePickerHandler(
      attachments: AttachmentRepository(_db!),
      baseDir: baseDir,
    );

    final result = await handler.pickAndStore(noteId: _note!.id);
    if (result == null || !mounted) return;

    // Refresh the checklist editor's attachment list.
    setState(() {});
    _dirty = true;
  }

  Future<void> _openChecklistAttachment(Attachment attachment) async {
    if (attachment.type == AttachmentType.doodleLayer) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => DoodleCanvasScreen(
            noteId: _note!.id,
            attachmentId: attachment.id,
          ),
        ),
      );
      return;
    }

    final file = File(attachment.filePath);
    if (!file.existsSync() || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(file, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  /// Persists an edited checklist title and keeps the app bar in sync.
  Future<void> _updateChecklistTitle(String title) async {
    if (_note == null) return;
    if (_title != title) {
      setState(() => _title = title);
    }
    await NoteRepository(_db!).updateNote(_note!.id, title: title);
  }

  /// Creates a doodle and stores it as a checklist attachment.
  Future<void> _insertChecklistDoodle() async {
    if (_note == null) return;
    unawaited(HapticFeedback.lightImpact());
    final noteId = _note!.id;

    final attachmentId = const Uuid().v4();

    // Create the attachment row for the doodle.
    final attachmentRepo = AttachmentRepository(_db!);
    final baseDir = await getApplicationDocumentsDirectory();
    final doodlePath = '${baseDir.path}/$attachmentId.doodle.json';
    await attachmentRepo.addDoodle(
      noteId: noteId,
      filePath: doodlePath,
      id: attachmentId,
    );

    // Open the doodle canvas.
    if (!mounted) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DoodleCanvasScreen(
          noteId: noteId,
          attachmentId: attachmentId,
        ),
      ),
    );

    if (!mounted || result == null) return;

    // Regenerate the thumbnail.
    final storage = DoodleStorage(
      attachments: attachmentRepo,
      baseDir: baseDir,
    );
    final data = await storage.loadDoodle(result);
    if (!mounted) return;
    final noteScheme = noteSchemeFor(context, _colorSeed);
    final thumbBytes = await DoodleThumbnailRenderer.render(
      data.strokes,
      background: data.background,
      noteScheme: noteScheme,
    );

    final thumbFile = File('${baseDir.path}/${result}_thumb.png');
    await thumbFile.writeAsBytes(thumbBytes);

    // Update the attachment's thumbnail path.
    await attachmentRepo.updateThumbnail(result, thumbFile.path);

    // Refresh the checklist editor.
    setState(() {});
    _dirty = true;
  }

  /// Creates a new doodle block and opens the doodle canvas.
  Future<void> _insertDoodle() async {
    if (_note == null || _editorState == null) return;
    unawaited(HapticFeedback.lightImpact());

    final attachmentId = const Uuid().v4();

    // Insert a placeholder doodle node (uses insertBlockNode for reliable placement).
    final node = doodleNode(attachmentId: attachmentId);
    final liveNode = insertBlockNode(_editorState!, node);

    // Force an empty paragraph after the doodle so the user can keep typing.
    final pNode = paragraphNode();
    insertBlockNode(_editorState!, pNode);

    // Open the canvas for the new doodle — use the live in-tree node so
    // _openDoodleCanvas's updateNode targets the correct path.
    await _openDoodleCanvas(liveNode, _editorState!);
    _scheduleAutosave();
  }

  /// Removes a doodle or image block from the document and deletes the
  /// associated attachment row + files from disk.
  Future<void> _deleteMediaBlock(Node node, EditorState editorState) async {
    if (_db == null || _note == null) return;
    unawaited(HapticFeedback.lightImpact());

    final repo = AttachmentRepository(_db!);

    // 1. Clean up attachment row + files from disk.
    if (node.type == DoodleBlockKeys.type) {
      final attId = node.attributes[DoodleBlockKeys.attachmentId] as String?;
      if (attId != null) {
        final att = await repo.getById(attId);
        if (att != null) await repo.deleteAttachmentWithFiles(att);
      }
    } else if (node.type == ImageBlockKeys.type) {
      final url = node.attributes[ImageBlockKeys.url] as String?;
      if (url != null && url.isNotEmpty) {
        final att = await repo.getByFilePath(url);
        if (att != null) await repo.deleteAttachmentWithFiles(att);
      }
    }

    // 2. Remove the node from the document, keeping a valid selection.
    final nodePath = node.path;
    final parentPath = nodePath.sublist(0, nodePath.length - 1);
    final index = nodePath.last;
    final siblings = node.parent?.children.toList() ?? [];
    final hasNext = index < siblings.length - 1;

    final transaction = editorState.transaction;
    transaction.deleteNode(node);

    if (siblings.length <= 1) {
      // Deleting the only block — insert a fresh paragraph.
      transaction.insertNode(const [0], paragraphNode());
      transaction.afterSelection =
          Selection.collapsed(Position(path: const [0]));
    } else if (hasNext) {
      // Next sibling slides into the deleted index.
      transaction.afterSelection =
          Selection.collapsed(Position(path: [...parentPath, index]));
    } else {
      // No next sibling — fall back to the previous one.
      transaction.afterSelection =
          Selection.collapsed(Position(path: [...parentPath, index - 1]));
    }

    await editorState.apply(transaction);
    _scheduleAutosave();
    setState(() {});
  }

  /// Deletes an attachment from a checklist note.
  Future<void> _deleteChecklistAttachment(Attachment attachment) async {
    if (_db == null) return;
    unawaited(HapticFeedback.lightImpact());
    final repo = AttachmentRepository(_db!);
    await repo.deleteAttachmentWithFiles(attachment);
    setState(() {});
  }

  /// Returns the editor widget appropriate for the current platform.
  ///
  /// Mobile platforms get [MobileToolbarV2] (keyboard toolbar).
  /// Desktop / web get [AppFlowyEditor] directly with desktop style
  /// (slash menu, selection menu, and app bar handle all actions).
  Widget _buildEditorForPlatform({
    required ColorScheme noteScheme,
    required TextTheme dynamicTextTheme,
  }) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    final editor = AppFlowyEditor(
      editorState: _editorState!,
      editorStyle: isMobile
          ? EditorStyle.mobile(
              cursorColor: noteScheme.primary,
              selectionColor: noteScheme.primary.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyleConfiguration: TextStyleConfiguration(
                text: dynamicTextTheme.bodyLarge!.copyWith(
                  color: noteScheme.onSurface,
                  height: 1.65,
                ),
              ),
            )
          : EditorStyle.desktop(
              cursorColor: noteScheme.primary,
              selectionColor: noteScheme.primary.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              textStyleConfiguration: TextStyleConfiguration(
                text: dynamicTextTheme.bodyLarge!.copyWith(
                  color: noteScheme.onSurface,
                  height: 1.65,
                ),
              ),
            ),
      autoFocus: true,
      blockComponentBuilders: {
        ...standardBlockComponentBuilderMap,
        TodoListBlockKeys.type: NookTodoListBlock.builder(),
        DoodleBlockKeys.type: DoodleBlockComponentBuilder(
          configuration: BlockComponentConfiguration(
            padding: (_) => const EdgeInsets.symmetric(vertical: 24),
          ),
          onTap: (node, editorState) {
            HapticFeedback.lightImpact();
            _openDoodleCanvas(node, editorState);
          },
          onDelete: _deleteMediaBlock,
        ),
        ImageBlockKeys.type: NookImageBlockComponentBuilder(
          onDelete: _deleteMediaBlock,
        ),
      },
      characterShortcutEvents: [
        ...standardCharacterShortcutEvents,
        customSlashCommand(
          [
            ...standardSelectionMenuItems,
            SelectionMenuItem(
              getName: () => 'Doodle',
              icon: (editorState, isSelected, style) => SelectionMenuIconWidget(
                name: 'draw',
                isSelected: isSelected,
                style: style,
              ),
              keywords: ['doodle', 'draw', 'sketch'],
              handler: (editorState, _, __) async {
                await _insertDoodle();
              },
            ),
          ],
        ),
      ],
    );

    if (isMobile) {
      return MobileToolbarV2(
        editorState: _editorState!,
        backgroundColor:
            noteScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        foregroundColor: noteScheme.onSurface,
        iconColor: noteScheme.onSurface,
        itemHighlightColor: noteScheme.primary,
        primaryColor: noteScheme.primary,
        onPrimaryColor: noteScheme.onPrimary,
        itemOutlineColor: noteScheme.outlineVariant.withValues(alpha: 0.4),
        toolbarItems: _buildMobileToolbarItems(),
        child: editor,
      );
    }

    return editor;
  }

  /// Builds the mobile toolbar items shown above the on-screen keyboard.
  ///
  /// The custom blocks menu mirrors the block-type shortcuts a desktop user
  /// gets from the slash menu, and the Doodle item opens the doodle canvas
  /// directly (it is an action, not a block-type toggle).
  List<MobileToolbarItem> _buildMobileToolbarItems() {
    return [
      MobileToolbarItem.withMenu(
        itemIconBuilder: (context, editorState, _) => AFMobileIcon(
          afMobileIcons: AFMobileIcons.list,
          color: MobileToolbarTheme.of(context).iconColor,
        ),
        itemMenuBuilder: (context, editorState, _) {
          final selection = editorState.selection;
          if (selection == null) return const SizedBox.shrink();
          return _NookBlocksMenu(
            editorState: editorState,
            selection: selection,
          );
        },
      ),
      MobileToolbarItem.action(
        itemIconBuilder: (context, editorState, _) => Icon(
          Icons.gesture_rounded,
          color: MobileToolbarTheme.of(context).iconColor,
        ),
        actionHandler: (context, editorState) {
          unawaited(_insertDoodle());
        },
      ),
      textDecorationMobileToolbarItemV2,
    ];
  }

  void _undoEditor() {
    final state = _editorState;
    if (state == null || !state.undoManager.undoStack.isNonEmpty) return;
    HapticFeedback.selectionClick();
    state.undoManager.undo();
    _scheduleAutosave();
    setState(() {});
  }

  void _redoEditor() {
    final state = _editorState;
    if (state == null || !state.undoManager.redoStack.isNonEmpty) return;
    HapticFeedback.selectionClick();
    state.undoManager.redo();
    _scheduleAutosave();
    setState(() {});
  }

  /// Exports the current note as a PNG and offers save-to-gallery / share.
  Future<void> _exportNote() async {
    if (_note == null || _editorState == null || !mounted) return;
    unawaited(HapticFeedback.lightImpact());
    await _save();
    if (!mounted || _note == null || _editorState == null) return;

    final boundaryKey = GlobalKey();
    final checklistItems = _note!.type == NoteType.checklist
        ? await ChecklistItemRepository(_db!).getItems(_note!.id)
        : const <ChecklistItem>[];
    if (!mounted) return;

    // Build the render widget off-screen inside an Overlay.
    // Use a Stack with overflow to allow the capture to render at intrinsic height.
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned(
            top: -10000,
            left: -10000,
            child: RepaintBoundary(
              key: boundaryKey,
              child: NoteExportCapture(
                note: _note!,
                editorState: _editorState!,
                checklistItems: checklistItems,
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);

    // Allow layout, then capture.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      final boundary = boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        entry.remove();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed: could not capture')),
        );
        return;
      }
      final bytes = await NoteExporter.captureBoundaryToPng(boundary);
      entry.remove();

      if (!mounted) return;

      // Show the preview dialog.
      await _showExportPreview(bytes);
    } catch (e) {
      entry.remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  /// Shows a preview of the exported PNG with share and save actions.
  Future<void> _showExportPreview(Uint8List bytes) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ExportPreviewSheet(bytes: bytes, noteTitle: _title),
    );

    if (!mounted || result == null) return;

    final baseDir = await getApplicationDocumentsDirectory();
    final filePath = '${baseDir.path}/${NoteExporter.generateFileName(_title)}';
    await File(filePath).writeAsBytes(bytes);

    if (result == 'share') {
      await NoteExporter.sharePng(filePath);
    } else if (result == 'gallery') {
      final saved = await NoteExporter.saveToGallery(
        bytes,
        name: NoteExporter.generateFileName(_title),
      );
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              saved ? 'Saved to gallery' : 'Gallery permission denied',
            ),
            action: saved
                ? SnackBarAction(
                    label: 'Share',
                    onPressed: () => NoteExporter.sharePng(filePath),
                  )
                : null,
          ),
        );
      }
    }
  }

  /// Opens the full-screen doodle canvas for the given [node].
  ///
  /// When the canvas saves, it pops with an [attachmentId]. We then
  /// regenerate a thumbnail and persist it back to the editor document
  /// via a [Transaction] so the inline doodle block stays in sync.
  Future<void> _openDoodleCanvas(Node node, EditorState editorState) async {
    if (_note == null) return;

    final attId = node.attributes[DoodleBlockKeys.attachmentId] as String?;
    if (attId == null) return;

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DoodleCanvasScreen(
          noteId: _note!.id,
          attachmentId: attId,
        ),
      ),
    );

    if (!mounted || result == null) return;

    // Regenerate the thumbnail for the updated doodle.
    final baseDir = await getApplicationDocumentsDirectory();
    final storage = DoodleStorage(
      attachments: AttachmentRepository(_db!),
      baseDir: baseDir,
    );
    final data = await storage.loadDoodle(result);
    if (!mounted) return;
    final noteScheme = noteSchemeFor(context, _colorSeed);
    final thumbBytes = await DoodleThumbnailRenderer.render(
      data.strokes,
      background: data.background,
      noteScheme: noteScheme,
    );

    final thumbFile = File('${baseDir.path}/${result}_thumb.png');
    await thumbFile.writeAsBytes(thumbBytes);

    // Update the attachment's thumbnail path in the database.
    await AttachmentRepository(_db!).updateThumbnail(result, thumbFile.path);

    // Persist the new thumbnail path back to the editor document node.
    final transaction = editorState.transaction;
    transaction.updateNode(node, {
      DoodleBlockKeys.thumbnailPath: thumbFile.path,
      DoodleBlockKeys.backgroundTemplate: data.background.name,
    });
    await editorState.apply(transaction);

    // Trigger autosave of the updated document content.
    _scheduleAutosave();
  }

  @override
  void dispose() {
    _disposed = true;
    _autosaveTimer?.cancel();
    _transactionSubscription?.cancel();
    // Snapshot content synchronously before EditorState is disposed.
    final note = _note;
    final db = _db;
    if (note != null && db != null && _editorState != null && _dirty) {
      final snapshot = _snapshotContent(note.id, db);
      _editorState?.dispose();
      super.dispose();
      // Fire-and-forget final write with the captured snapshot.
      _persistSnapshot(snapshot);
      return;
    }
    _editorState?.dispose();
    super.dispose();
  }

  /// Serializes the editor state to a snapshot without async gaps.
  _PersistSnapshot _snapshotContent(String noteId, AppDatabase db) {
    final nodes = _editorState!.document.root.children;
    String plainText = '';
    for (final node in nodes) {
      if (node.delta != null) {
        for (final op in node.delta!.toList()) {
          if (op is TextInsert) plainText += op.text;
        }
        plainText += '\n';
      }
    }
    plainText = plainText.trim();
    final derivedTitle = plainText.split('\n').firstOrNull ?? _title;
    return _PersistSnapshot(
      noteId: noteId,
      title: derivedTitle != _title ? derivedTitle : null,
      deltaJson: jsonEncode(_editorState!.document.toJson()),
      plainText: plainText,
      db: db,
    );
  }

  /// Writes a pre-captured snapshot to the database, ignoring errors.
  Future<void> _persistSnapshot(_PersistSnapshot snapshot) async {
    try {
      final repo = NoteRepository(snapshot.db);
      if (snapshot.title != null) {
        await repo.updateNote(snapshot.noteId, title: snapshot.title!);
      }
      await repo.updateContent(
        snapshot.noteId,
        deltaContent: snapshot.deltaJson,
        plainText: snapshot.plainText,
      );
    } catch (_) {
      // Best-effort — app is navigating away.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    if (_loading) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
      );
    }

    if (_editorState == null) {
      return Scaffold(
        backgroundColor: scheme.surface,
        body: Center(
          child: Text(
            'Failed to load note',
            style: TextStyle(color: scheme.onSurface),
          ),
        ),
      );
    }

    final noteScheme = noteSchemeFor(context, _colorSeed);

    final dynamicTextTheme =
        NoteThemeScope.buildDynamicTextTheme(context, noteScheme);

    // Build the Hero outside NoteThemeScope to avoid _dependents.isEmpty
    // assertion during route pop Hero flights. The Hero's child is a plain
    // ColoredBox using a captured Color — no inherited deps needed.
    final heroChild = widget.noteId != null
        ? Positioned.fill(
            child: Hero(
              tag: 'note-${widget.noteId}',
              child: ColoredBox(color: noteScheme.surfaceContainerLowest),
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        heroChild,
        NoteThemeScope(
          colorScheme: noteScheme,
          textTheme: dynamicTextTheme,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: noteScheme.surfaceContainerLowest,
            body: Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: topPadding + 90,
                        bottom: keyboardHeight + 120,
                      ),
                      sliver: SliverFillRemaining(
                        hasScrollBody: true,
                        child: _note?.type == NoteType.checklist
                            ? ChecklistEditor(
                                noteId: _note!.id,
                                title: _title,
                                onTitleChanged: _updateChecklistTitle,
                                onInsertImage: _note != null
                                    ? _insertChecklistImage
                                    : null,
                                onInsertDoodle: _note != null
                                    ? _insertChecklistDoodle
                                    : null,
                                onOpenAttachment: _note != null
                                    ? _openChecklistAttachment
                                    : null,
                                onDeleteAttachment: _note != null
                                    ? _deleteChecklistAttachment
                                    : null,
                              )
                            : _buildEditorForPlatform(
                                noteScheme: noteScheme,
                                dynamicTextTheme: dynamicTextTheme,
                              ),
                      ),
                    ),
                  ],
                ),

                // 2. Auto-Hiding Glass App Bar (Zen Mode)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutBack,
                  top: isKeyboardVisible ? -100 : topPadding + 12,
                  left: 20,
                  right: 20,
                  child: RepaintBoundary(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: isKeyboardVisible ? 0.0 : 1.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: noteScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: _ResponsiveEditorAppBar(
                              noteScheme: noteScheme,
                              dynamicTextTheme: dynamicTextTheme,
                              title: _title,
                              saving: _saving,
                              pinned: _pinned,
                              note: _note,
                              onBack: () async {
                                final router = GoRouter.of(context);
                                unawaited(HapticFeedback.lightImpact());
                                // Delete newly-created blank notes on exit.
                                if (_dirty) {
                                  final nodes =
                                      _editorState!.document.root.children;
                                  String plainText = '';
                                  for (final node in nodes) {
                                    if (node.delta != null) {
                                      for (final op in node.delta!.toList()) {
                                        if (op is TextInsert) {
                                          plainText += op.text;
                                        }
                                      }
                                      plainText += '\n';
                                    }
                                  }
                                  plainText = plainText.trim();
                                  if (plainText.isEmpty &&
                                      _title.isEmpty &&
                                      widget.noteId == null) {
                                    await NoteRepository(_db!)
                                        .permanentlyDelete(_note!.id);
                                  } else {
                                    await _save();
                                  }
                                }
                                if (mounted) router.pop();
                              },
                              onInsertImage: _insertImage,
                              onInsertDoodle: _insertDoodle,
                              onTogglePin: _togglePin,
                              onExport: _exportNote,
                              onMoreOptions: _showNoteOptions,
                              canUndo: _editorState!
                                  .undoManager.undoStack.isNonEmpty,
                              canRedo: _editorState!
                                  .undoManager.redoStack.isNonEmpty,
                              onUndo: _undoEditor,
                              onRedo: _redoEditor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. (removed) Floating Formatting Pill — superseded by the
                // MobileToolbarV2 keyboard toolbar (see _buildMobileToolbarItems).
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveEditorAppBar extends StatelessWidget {
  const _ResponsiveEditorAppBar({
    required this.noteScheme,
    required this.dynamicTextTheme,
    required this.title,
    required this.saving,
    required this.pinned,
    required this.note,
    required this.onBack,
    required this.onInsertImage,
    required this.onInsertDoodle,
    required this.onTogglePin,
    required this.onExport,
    required this.onMoreOptions,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  final ColorScheme noteScheme;
  final TextTheme dynamicTextTheme;
  final String title;
  final bool saving;
  final bool pinned;
  final Note? note;
  final VoidCallback onBack;
  final VoidCallback onInsertImage;
  final VoidCallback onInsertDoodle;
  final VoidCallback onTogglePin;
  final VoidCallback onExport;
  final VoidCallback onMoreOptions;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;

        return Row(
          children: [
            IconButton(
              tooltip: 'Back',
              icon: Icon(
                Icons.arrow_back_rounded,
                color: noteScheme.onSurface,
              ),
              onPressed: onBack,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isNotEmpty ? title : 'New Note',
                    style: dynamicTextTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    saving
                        ? 'Saving...'
                        : DateFormat('MMMM d, yyyy')
                            .format(note?.updatedAt ?? DateTime.now()),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: noteScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isNarrow) ...[
              IconButton(
                tooltip: 'Undo',
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: canRedo ? onRedo : null,
                icon: const Icon(Icons.redo_rounded),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: noteScheme.onSurface,
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'image':
                      onInsertImage();
                    case 'doodle':
                      onInsertDoodle();
                    case 'pin':
                      onTogglePin();
                    case 'export':
                      onExport();
                    case 'more':
                      onMoreOptions();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'image',
                    child: Row(
                      children: [
                        Icon(Icons.add_photo_alternate_rounded,
                            size: 20, color: noteScheme.onSurface),
                        const SizedBox(width: 12),
                        const Text('Insert image'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'doodle',
                    child: Row(
                      children: [
                        Icon(Icons.draw_rounded,
                            size: 20, color: noteScheme.onSurface),
                        const SizedBox(width: 12),
                        const Text('Insert doodle'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pin',
                    child: Row(
                      children: [
                        Icon(
                          pinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          size: 20,
                          color: pinned
                              ? noteScheme.primary
                              : noteScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Text(pinned ? 'Unpin note' : 'Pin note'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.ios_share_rounded,
                            size: 20, color: noteScheme.onSurface),
                        const SizedBox(width: 12),
                        const Text('Export note'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'more',
                    child: Row(
                      children: [
                        Icon(Icons.settings_rounded,
                            size: 20, color: noteScheme.onSurface),
                        const SizedBox(width: 12),
                        const Text('Note options'),
                      ],
                    ),
                  ),
                ],
              )
            ] else ...[
              IconButton(
                tooltip: 'Undo',
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: canRedo ? onRedo : null,
                icon: const Icon(Icons.redo_rounded),
              ),
              IconButton(
                tooltip: 'Insert image',
                icon: Icon(
                  Icons.add_photo_alternate_rounded,
                  color: noteScheme.onSurface,
                ),
                onPressed: onInsertImage,
              ),
              IconButton(
                tooltip: 'Insert doodle',
                icon: Icon(
                  Icons.draw_rounded,
                  color: noteScheme.onSurface,
                ),
                onPressed: onInsertDoodle,
              ),
              IconButton(
                tooltip: pinned ? 'Unpin note' : 'Pin note',
                icon: Icon(
                  pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: pinned ? noteScheme.primary : noteScheme.onSurface,
                  size: 20,
                ),
                onPressed: onTogglePin,
              ),
              IconButton(
                tooltip: 'Export note',
                icon: Icon(
                  Icons.ios_share_rounded,
                  color: noteScheme.onSurface,
                  size: 20,
                ),
                onPressed: onExport,
              ),
              IconButton(
                tooltip: 'More options',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: noteScheme.onSurface,
                ),
                onPressed: onMoreOptions,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Minimal capture-only widget for exporting a note as PNG.
class NoteExportCapture extends StatelessWidget {
  const NoteExportCapture({
    super.key,
    required this.note,
    required this.editorState,
    this.checklistItems = const [],
  });

  final Note note;
  final EditorState editorState;
  final List<ChecklistItem> checklistItems;

  ColorScheme _noteScheme(BuildContext context) =>
      noteSchemeFor(context, note.colorSeed);

  @override
  Widget build(BuildContext context) {
    final scheme = _noteScheme(context);
    final nodes = editorState.document.root.children;

    return Material(
      color: scheme.surface,
      child: Container(
        width: 460,
        padding: const EdgeInsets.fromLTRB(72, 56, 72, 64),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMMM d, yyyy').format(note.updatedAt),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              note.title.isNotEmpty ? note.title : 'Untitled',
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ).copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            ...nodes.map((node) {
              final type = node.type;
              if (type == TodoListBlockKeys.type) {
                final checked =
                    node.attributes[TodoListBlockKeys.checked] ?? false;
                final delta = node.delta;
                String text = '';
                if (delta != null) {
                  for (final op in delta) {
                    if (op is TextInsert) text += op.text;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        checked ? Icons.check_circle : Icons.circle_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: 16,
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                            decoration:
                                checked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (type == ImageBlockKeys.type) {
                final url = node.attributes[ImageBlockKeys.url] as String?;
                if (url != null && File(url).existsSync()) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Image.file(File(url), width: 300),
                  );
                }
              }
              if (type == DoodleBlockKeys.type) {
                final path =
                    node.attributes[DoodleBlockKeys.thumbnailPath] as String?;
                if (path != null &&
                    path.isNotEmpty &&
                    File(path).existsSync()) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(path), width: 300),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
              final delta = node.delta;
              if (delta != null && delta.isNotEmpty) {
                String text = '';
                for (final op in delta) {
                  if (op is TextInsert) text += op.text;
                }
                if (text.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  );
                }
              }
              return const SizedBox.shrink();
            }),
            if (checklistItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...checklistItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.checked
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.itemText,
                          style: TextStyle(
                            fontSize: 16,
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                            decoration: item.checked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Divider(color: scheme.outlineVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'nook. / 2026',
              style: TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 10,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pre-captured editor content for a best-effort dispose save.
class _PersistSnapshot {
  const _PersistSnapshot({
    required this.noteId,
    required this.deltaJson,
    required this.plainText,
    required this.db,
    this.title,
  });

  final String noteId;
  final String? title;
  final String deltaJson;
  final String plainText;
  final AppDatabase db;
}

/// Bottom sheet showing a preview of the exported PNG with share/save actions.
class _ExportPreviewSheet extends StatelessWidget {
  const _ExportPreviewSheet({required this.bytes, required this.noteTitle});

  final Uint8List bytes;
  final String noteTitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Export Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Image.memory(
                  bytes,
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'share'),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, 'gallery'),
                  icon: const Icon(Icons.save_alt_rounded, size: 18),
                  label: const Text('Save to Gallery'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Grid menu shown by the mobile toolbar's custom blocks item.
///
/// Mirrors the block types a desktop user reaches through the `/` slash menu:
/// headings, bulleted/numbered lists, a checkbox, and a quote. Selecting an
/// already-selected block reverts it to a plain paragraph.
class _NookBlocksMenu extends StatefulWidget {
  const _NookBlocksMenu({
    required this.editorState,
    required this.selection,
  });

  final EditorState editorState;
  final Selection selection;

  @override
  State<_NookBlocksMenu> createState() => _NookBlocksMenuState();
}

class _NookBlocksMenuState extends State<_NookBlocksMenu> {
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
