import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/drift.dart' show Value;
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
import '../../core/theme/note_theme.dart';
import '../../core/theme/note_theme_scope.dart';
import '../../data/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/checklist_item_repository.dart';
import '../../data/repositories/doodle_storage.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';
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

  /// Creates a doodle and stores it as a checklist attachment.
  Future<void> _insertChecklistDoodle() async {
    if (_note == null) return;
    unawaited(HapticFeedback.lightImpact());

    final attachmentId = const Uuid().v4();

    // Create the attachment row for the doodle.
    final attachmentRepo = AttachmentRepository(_db!);
    final baseDir = await getApplicationDocumentsDirectory();
    final doodlePath = '${baseDir.path}/$attachmentId.doodle.json';
    await attachmentRepo.addDoodle(
      noteId: _note!.id,
      filePath: doodlePath,
      id: attachmentId,
    );

    // Open the doodle canvas.
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => DoodleCanvasScreen(
          noteId: _note!.id,
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
                                onInsertImage: _note != null
                                    ? _insertChecklistImage
                                    : null,
                                onInsertDoodle: _note != null
                                    ? _insertChecklistDoodle
                                    : null,
                              )
                            : AppFlowyEditor(
                                editorState: _editorState!,
                                editorStyle: EditorStyle.mobile(
                                  cursorColor: noteScheme.primary,
                                  selectionColor:
                                      noteScheme.primary.withValues(alpha: 0.2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  textStyleConfiguration:
                                      TextStyleConfiguration(
                                    text: dynamicTextTheme.bodyLarge!.copyWith(
                                      color: noteScheme.onSurface,
                                      height: 1.65,
                                    ),
                                  ),
                                ),
                                autoFocus: true,
                                blockComponentBuilders: {
                                  ...standardBlockComponentBuilderMap,
                                  TodoListBlockKeys.type:
                                      NookTodoListBlock.builder(),
                                  DoodleBlockKeys.type:
                                      DoodleBlockComponentBuilder(
                                    configuration: BlockComponentConfiguration(
                                      padding: (_) =>
                                          const EdgeInsets.symmetric(
                                              vertical: 24),
                                    ),
                                    onTap: (node, editorState) {
                                      HapticFeedback.lightImpact();
                                      _openDoodleCanvas(node, editorState);
                                    },
                                  ),
                                  ImageBlockKeys.type:
                                      NookImageBlockComponentBuilder(),
                                },
                                characterShortcutEvents: [
                                  ...standardCharacterShortcutEvents,
                                  customSlashCommand(
                                    [
                                      ...standardSelectionMenuItems,
                                      SelectionMenuItem(
                                        getName: () => 'Doodle',
                                        icon:
                                            (editorState, isSelected, style) =>
                                                SelectionMenuIconWidget(
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

                // 3. Floating Formatting Pill (Anchors to keyboard)
                if (_note?.type != NoteType.checklist)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    bottom: isKeyboardVisible ? keyboardHeight + 16 : -100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: RepaintBoundary(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: isKeyboardVisible ? 1.0 : 0.0,
                          child: _FloatingFormatBar(editorState: _editorState!),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FloatingFormatBar extends StatefulWidget {
  const _FloatingFormatBar({required this.editorState});

  final EditorState editorState;

  @override
  State<_FloatingFormatBar> createState() => _FloatingFormatBarState();
}

class _FloatingFormatBarState extends State<_FloatingFormatBar> {
  Selection? _selection;
  Map<String, dynamic> _toggledStyle = {};

  @override
  void initState() {
    super.initState();
    _selection = widget.editorState.selection;
    _toggledStyle = Map<String, dynamic>.from(
      widget.editorState.toggledStyle,
    );
    widget.editorState.selectionNotifier.addListener(_onSelectionChanged);
    widget.editorState.toggledStyleNotifier.addListener(_onStyleChanged);
  }

  @override
  void dispose() {
    widget.editorState.selectionNotifier.removeListener(_onSelectionChanged);
    widget.editorState.toggledStyleNotifier.removeListener(_onStyleChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (!mounted) return;
    setState(() => _selection = widget.editorState.selection);
  }

  void _onStyleChanged() {
    if (!mounted) return;
    setState(() {
      _toggledStyle = Map<String, dynamic>.from(
        widget.editorState.toggledStyle,
      );
    });
  }

  /// Whether [attribute] is active for the current selection.
  bool _isActive(String attribute) {
    final selection = _selection;
    if (selection == null) return false;

    if (selection.isCollapsed) {
      return _toggledStyle[attribute] == true;
    }

    // For a ranged selection, check if all selected nodes have the attribute.
    final nodes = widget.editorState.getNodesInSelection(selection);
    if (nodes.isEmpty) return false;

    for (final node in nodes) {
      final delta = node.delta;
      if (delta == null) continue;
      final attributes = delta.everyAttributes(
        (attr) => attr[attribute] == true,
      );
      if (attributes != true) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);

    return RepaintBoundary(
      child: ExcludeFocus(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FormatAction(
                    icon: Icons.format_bold_rounded,
                    tooltip: 'Bold',
                    isActive: _isActive('bold'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.editorState.toggleAttribute('bold');
                    },
                  ),
                  _FormatAction(
                    icon: Icons.format_italic_rounded,
                    tooltip: 'Italic',
                    isActive: _isActive('italic'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.editorState.toggleAttribute('italic');
                    },
                  ),
                  _FormatAction(
                    icon: Icons.format_strikethrough_rounded,
                    tooltip: 'Strikethrough',
                    isActive: _isActive('strikethrough'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.editorState.toggleAttribute('strikethrough');
                    },
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    child: VerticalDivider(
                      width: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  _FormatAction(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: 'Bullet list',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      insertBlockNode(
                        widget.editorState,
                        bulletedListNode(),
                      );
                    },
                  ),
                  _FormatAction(
                    icon: Icons.checklist_rounded,
                    tooltip: 'Checklist',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      insertBlockNode(
                        widget.editorState,
                        todoListNode(checked: false),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatAction extends StatelessWidget {
  const _FormatAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    return Semantics(
      label: tooltip,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 22,
            color: isActive
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
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
