import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/database_provider.dart';
import '../../core/router.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/note_theme.dart';
import '../../core/theme/note_theme_scope.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../data/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/checklist_item_repository.dart';
import '../../data/repositories/doodle_storage.dart';
import '../../data/repositories/note_link_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/tables/attachments.dart';
import '../../data/tables/notes.dart';
import '../../features/doodle/doodle_canvas_screen.dart';
import '../../features/doodle/doodle_thumbnail_renderer.dart';
import '../security/vault_password_dialog.dart';
import 'doodle/doodle_block.dart';
import 'editor_autosave.dart';
import 'editor_body.dart';
import 'editor_sheets.dart';
import 'editor_title.dart';
import 'note_exporter.dart';
import 'widgets/image_picker_handler.dart';
import 'widgets/note_link_picker.dart';
import 'widgets/backlinks_panel.dart';
import 'widgets/editor_outline.dart';

export 'editor_autosave.dart';
export 'editor_body.dart' show insertBlockNode;
export 'editor_sheets.dart'
    show NoteExportCapture, ExportPreviewSheet, showPaperStyleSheet;
export 'editor_title.dart' show ResponsiveEditorAppBar;
export 'editor_toolbar.dart' show NookBlocksMenu, buildMobileToolbarItems;

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
  bool _disposed = false;
  String? _colorSeed;
  String? _notebookId;
  String? _notebookName;
  List<String> _tagNames = [];
  StreamSubscription<void>? _transactionSubscription;
  AppDatabase? _db;
  bool _corruptedDelta = false;
  List<Attachment> _checklistAttachments = [];
  NotePaperStyle _paperStyle = NotePaperStyle.blank;
  bool _focusMode = false;
  NoteFontStyle _fontStyle = NoteFontStyle.auto;
  bool _readOnly = false;
  bool _showSavedFeedback = false;

  final EditorAutosaveController _autosaveController =
      EditorAutosaveController();

  /// Version counter for undo/redo stack changes — lets the app bar rebuild
  /// without forcing the entire editor screen to rebuild via setState.
  final ValueNotifier<int> _undoRedoVersion = ValueNotifier<int>(0);

  int get _wordCount {
    if (_editorState == null) return 0;
    final nodes = _editorState!.document.root.children;
    int words = 0;
    for (final node in nodes) {
      if (node.delta != null) {
        for (final op in node.delta!.toList()) {
          final data = op.data;
          if (data is String) {
            final trimmed = data.trim();
            if (trimmed.isNotEmpty) {
              words += trimmed.split(RegExp(r'\s+')).length;
            }
          }
        }
      }
    }
    return words;
  }

  int get _readingTime =>
      _wordCount > 0 ? max(1, (_wordCount / 200).ceil()) : 0;

  bool get _hasDoodleBlock {
    if (_editorState == null) return false;
    return _editorState!.document.root.children
        .any((n) => n.type == DoodleBlockKeys.type);
  }

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
      _fontStyle = parseFontStyle(note.fontStyle);
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
          _cleanupInit();
          if (!_disposed && mounted) context.pop();
          return;
        }
        // Vault password (C1): when enabled, locked notes need a second secret.
        if (!_disposed && mounted) {
          final vaultOk = await ensureVaultUnlocked(
            context,
            ref,
            reason: 'This note is locked — enter your vault password',
          );
          if (_disposed || !mounted) {
            _cleanupInit();
            return;
          }
          if (!vaultOk) {
            context.pop();
            return;
          }
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
        await repo.permanentlyDelete(note.id);
        _cleanupInit();
        return;
      }
      _note = note;
      _editorState = EditorState.blank(withInitialText: true);
    }

    _fontStyle = parseFontStyle(_note?.fontStyle);

    if (_disposed || !mounted) {
      _cleanupInit();
      return;
    }

    _transactionSubscription = _editorState!.transactionStream.listen((_) {
      _autosaveController.markDirty();
      _autosaveController.scheduleAutosave(onSave: _save);
    });

    if (_note?.type == NoteType.checklist) {
      _checklistAttachments =
          await AttachmentRepository(_db!).getAllForNote(_note!.id);
    }

    if (_note != null) {
      final tagRepo = TagRepository(_db!);
      final tags = await tagRepo.getTagsForNote(_note!.id);
      _tagNames = tags.map((t) => t.name).toList();

      if (_note!.notebookId != null) {
        final nbRepo = NotebookRepository(_db!);
        final nb = await nbRepo.getNotebookById(_note!.notebookId!);
        _notebookName = nb?.name;
      }
    }

    if (!mounted) {
      _cleanupInit();
      return;
    }
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
          SnackBar(
            content: const Text(
              'Note content was corrupted. A fresh document was started.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Copy raw',
              onPressed: () {
                final raw = _note?.deltaContent;
                if (raw != null) {
                  Clipboard.setData(ClipboardData(text: raw));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Raw JSON copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      });
    }
  }

  void _cleanupInit() {
    _editorState?.dispose();
    _editorState = null;
  }

  bool _isEffectivelyEmpty() {
    if (_editorState == null) return true;
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
    return plainText.trim().isEmpty && _title.isEmpty;
  }

  Future<void> _save() async {
    await _autosaveController.save(
      editorState: _editorState,
      note: _note,
      db: _db,
      currentTitle: _title,
      isDisposed: _disposed,
      onSaved: (derivedTitle, updatedNote) {
        if (mounted) {
          setState(() {
            _title = derivedTitle;
            _note = updatedNote;
            _fontStyle = parseFontStyle(updatedNote.fontStyle);
            _showSavedFeedback = true;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showSavedFeedback = false);
          });
        } else {
          _title = derivedTitle;
          _note = updatedNote;
          _fontStyle = parseFontStyle(updatedNote.fontStyle);
        }
      },
    );
  }

  Future<void> _pickColor() async {
    if (_note == null || _db == null) return;
    final newSeed = await pickEditorColor(
      context: context,
      db: _db!,
      note: _note!,
      currentColorSeed: _colorSeed,
    );
    if (mounted && newSeed != _colorSeed) {
      setState(() => _colorSeed = newSeed);
    }
  }

  Future<void> _showPaperStyleSheet() async {
    final selected = await showPaperStyleSheet(
      context,
      currentStyle: _paperStyle,
    );
    if (selected != null && mounted) {
      setState(() => _paperStyle = selected);
    }
  }

  Future<void> _showOutline() async {
    final state = _editorState;
    if (state == null || !mounted) return;
    final entry = await showEditorOutlineSheet(
      context,
      document: state.document,
    );
    if (entry == null || !mounted || _editorState == null) return;
    // Jump the scroll view to the heading's top-level block first so its
    // render box exists, then place the cursor on it — the editor's scroll
    // service auto-scrolls the selection into view afterwards.
    _editorState!.scrollService?.jumpTo(entry.path.first);
    _editorState!.selection = Selection.collapsed(
      Position(path: entry.path),
    );
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
    if (_note == null || _db == null) return;
    final repo = NoteRepository(_db!);

    await showEditorNoteOptions(
      context: context,
      db: _db!,
      note: _note!,
      currentNotebookId: _notebookId,
      currentColorSeed: _colorSeed,
      currentFontStyle: _fontStyle,
      currentReadOnly: _readOnly,
      currentlyLocked: _locked,
      onNotebookChanged: (id) async {
        _notebookId = id;
        await repo.updateNote(_note!.id, notebookId: id);
      },
      onColorChanged: (color) {
        if (mounted) setState(() => _colorSeed = color);
      },
      onFontStyleChanged: (style) async {
        if (mounted) setState(() => _fontStyle = style);
        await repo.updateNote(_note!.id, fontStyle: style);
      },
      onReadOnlyChanged: (readOnly) {
        if (mounted) setState(() => _readOnly = readOnly);
      },
      onTagsChanged: (tagIds) async {
        await repo.updateNoteTags(_note!.id, tagIds);
      },
      onLockedChanged: (locked) {
        if (mounted) setState(() => _locked = locked);
      },
    );
  }

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

    final node = imageNode(url: result.filePath);
    insertBlockNode(_editorState!, node);

    final pNode = paragraphNode();
    insertBlockNode(_editorState!, pNode);

    _autosaveController.markDirty();
    _autosaveController.scheduleAutosave(onSave: _save);
  }

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

    final attachments =
        await AttachmentRepository(_db!).getAllForNote(_note!.id);
    if (!mounted) return;
    setState(() => _checklistAttachments = attachments);
    _autosaveController.markDirty();
  }

  Future<void> _openChecklistAttachment(Attachment attachment) async {
    if (attachment.type == AttachmentType.doodleLayer) {
      await Navigator.of(context).push<void>(
        EditorialPageRoute(
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

  Future<void> _updateChecklistTitle(String title) async {
    if (_note == null) return;
    if (_title != title) {
      setState(() => _title = title);
    }
    await NoteRepository(_db!).updateNote(_note!.id, title: title);
  }

  Future<void> _insertChecklistDoodle() async {
    if (_note == null) return;
    unawaited(HapticFeedback.lightImpact());
    final noteId = _note!.id;
    final attachmentId = const Uuid().v4();

    final attachmentRepo = AttachmentRepository(_db!);
    final baseDir = await getApplicationDocumentsDirectory();
    final doodlePath = '${baseDir.path}/$attachmentId.doodle.json';
    await attachmentRepo.addDoodle(
      noteId: noteId,
      filePath: doodlePath,
      id: attachmentId,
    );

    if (!mounted) return;
    final result = await Navigator.of(context).push<String>(
      EditorialPageRoute(
        builder: (_) => DoodleCanvasScreen(
          noteId: noteId,
          attachmentId: attachmentId,
        ),
      ),
    );

    if (!mounted || result == null) return;

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
    await attachmentRepo.updateThumbnail(result, thumbFile.path);

    final attachments =
        await AttachmentRepository(_db!).getAllForNote(_note!.id);
    setState(() => _checklistAttachments = attachments);
    _autosaveController.markDirty();
  }

  Future<void> _insertDoodle() async {
    if (_note == null || _editorState == null) return;
    unawaited(HapticFeedback.lightImpact());

    final attachmentId = const Uuid().v4();
    final node = doodleNode(attachmentId: attachmentId);
    final liveNode = insertBlockNode(_editorState!, node);

    final pNode = paragraphNode();
    insertBlockNode(_editorState!, pNode);

    await _openDoodleCanvas(liveNode, _editorState!);
    _autosaveController.scheduleAutosave(onSave: _save);
  }

  Future<void> _deleteMediaBlock(Node node, EditorState editorState) async {
    if (_db == null || _note == null || !mounted) return;

    final mediaType = node.type == DoodleBlockKeys.type ? 'doodle' : 'image';
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete $mediaType?',
      message:
          'This $mediaType will be moved to trash and can be restored later.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    unawaited(HapticFeedback.lightImpact());
    final repo = AttachmentRepository(_db!);

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

    final nodePath = node.path;
    final parentPath = nodePath.sublist(0, nodePath.length - 1);
    final index = nodePath.last;
    final siblings = node.parent?.children.toList() ?? [];
    final hasNext = index < siblings.length - 1;

    final transaction = editorState.transaction;
    transaction.deleteNode(node);

    if (siblings.length <= 1) {
      transaction.insertNode(const [0], paragraphNode());
      transaction.afterSelection =
          Selection.collapsed(Position(path: const [0]));
    } else if (hasNext) {
      transaction.afterSelection =
          Selection.collapsed(Position(path: [...parentPath, index]));
    } else {
      transaction.afterSelection =
          Selection.collapsed(Position(path: [...parentPath, index - 1]));
    }

    await editorState.apply(transaction);
    _autosaveController.scheduleAutosave(onSave: _save);
    _undoRedoVersion.value++;
  }

  Future<void> _deleteChecklistAttachment(Attachment attachment) async {
    if (_db == null || !mounted) return;

    final mediaType =
        attachment.type == AttachmentType.doodleLayer ? 'doodle' : 'image';
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: 'Delete $mediaType?',
      message:
          'This $mediaType will be moved to trash and can be restored later.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;

    unawaited(HapticFeedback.lightImpact());
    final repo = AttachmentRepository(_db!);
    await repo.deleteAttachmentWithFiles(attachment);
    final attachments =
        await AttachmentRepository(_db!).getAllForNote(_note!.id);
    if (!mounted) return;
    setState(() => _checklistAttachments = attachments);
  }

  Future<void> _insertNoteLink() async {
    if (_editorState == null || _note == null || !mounted) return;
    final pick = await showNoteLinkPicker(
      context,
      excludeNoteId: _note!.id,
    );
    if (pick == null || !mounted || _editorState == null) return;

    final editorState = _editorState!;
    final pos =
        editorState.selection?.start ?? Position(path: const [0], offset: 0);
    final node = editorState.getNodeAtPath(pos.path);
    if (node == null) return;

    final label = pick.title.trim().isEmpty ? 'Untitled' : pick.title.trim();
    final transaction = editorState.transaction;
    transaction.replaceText(
      node,
      pos.offset,
      0,
      label,
      attributes: {
        AppFlowyRichTextKeys.href: noteLinkUri(pick.noteId),
      },
    );
    await editorState.apply(transaction);
    _autosaveController.scheduleAutosave(onSave: _save);
  }

  void _undoEditor() {
    final state = _editorState;
    if (state == null || !state.undoManager.undoStack.isNonEmpty) return;
    HapticFeedback.selectionClick();
    state.undoManager.undo();
    _autosaveController.scheduleAutosave(onSave: _save);
    _undoRedoVersion.value++;
  }

  void _redoEditor() {
    final state = _editorState;
    if (state == null || !state.undoManager.redoStack.isNonEmpty) return;
    HapticFeedback.selectionClick();
    state.undoManager.redo();
    _autosaveController.scheduleAutosave(onSave: _save);
    _undoRedoVersion.value++;
  }

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

    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      final flashEntry = OverlayEntry(
        builder: (_) => ColoredBox(
          color: Theme.of(context).colorScheme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.2),
        ),
      );
      Overlay.of(context).insert(flashEntry);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      flashEntry.remove();
    }

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
      await _showExportPreview(bytes);
    } catch (e) {
      entry.remove();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

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
      builder: (_) => ExportPreviewSheet(bytes: bytes, noteTitle: _title),
    );

    if (!mounted || result == null) return;

    final fileName = NoteExporter.generateFileName(_title);
    String? path = await NoteExporter.saveToExportsFolder(
      bytes,
      fileName: fileName,
    );
    if (path == null) {
      final baseDir = await getApplicationDocumentsDirectory();
      path = '${baseDir.path}/$fileName';
      await File(path).writeAsBytes(bytes);
    }
    final filePath = path;

    if (result == 'share') {
      final exportResult = await NoteExporter.sharePng(filePath);
      if (mounted && !exportResult.isSuccess) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(exportResult.message)),
        );
      }
    } else if (result == 'gallery') {
      final exportResult = await NoteExporter.saveToGallery(
        bytes,
        name: fileName,
      );
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              exportResult.isSuccess
                  ? 'Saved to gallery'
                  : exportResult.message,
            ),
            action: exportResult.isSuccess
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

  Future<void> _openDoodleCanvas(Node node, EditorState editorState) async {
    if (_note == null) return;

    final attId = node.attributes[DoodleBlockKeys.attachmentId] as String?;
    if (attId == null) return;

    final result = await Navigator.of(context).push<String>(
      EditorialPageRoute(
        builder: (_) => DoodleCanvasScreen(
          noteId: _note!.id,
          attachmentId: attId,
        ),
      ),
    );

    if (!mounted || result == null) return;

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
    await AttachmentRepository(_db!).updateThumbnail(result, thumbFile.path);

    final transaction = editorState.transaction;
    transaction.updateNode(node, {
      DoodleBlockKeys.thumbnailPath: thumbFile.path,
      DoodleBlockKeys.backgroundTemplate: data.background.name,
    });
    await editorState.apply(transaction);

    _autosaveController.scheduleAutosave(onSave: _save);
  }

  @override
  void dispose() {
    _disposed = true;
    _transactionSubscription?.cancel();
    _undoRedoVersion.dispose();

    _autosaveController.dispose(
      editorState: _editorState,
      note: _note,
      db: _db,
      currentTitle: _title,
      dirty: _autosaveController.isDirty,
    );

    _editorState?.dispose();
    super.dispose();
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedNote01,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load note',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The note may have been deleted or is corrupted.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.pop(),
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowLeft01,
                  size: 18,
                ),
                label: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    final noteScheme = noteSchemeFor(context, _colorSeed);
    final dynamicTextTheme = NoteThemeScope.buildDynamicTextTheme(
      context,
      noteScheme,
      fontStyle: _fontStyle,
    );

    final heroChild = widget.noteId != null
        ? Positioned.fill(
            child: Hero(
              tag: 'note-${widget.noteId}',
              child: ColoredBox(color: noteScheme.surfaceContainerLowest),
            ),
          )
        : const SizedBox.shrink();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Stack(
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
                          top: _focusMode
                              ? topPadding + 16
                              : (isKeyboardVisible
                                  ? topPadding + 16
                                  : topPadding + 90),
                          bottom: keyboardHeight + 120,
                        ),
                        sliver: SliverFillRemaining(
                          hasScrollBody: true,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: EditorBody(
                                editorState: _editorState!,
                                note: _note,
                                noteScheme: noteScheme,
                                dynamicTextTheme: dynamicTextTheme,
                                paperStyle: _paperStyle,
                                readOnly: _readOnly,
                                hasDoodleBlock: _hasDoodleBlock,
                                onInsertDoodle: _insertDoodle,
                                onInsertImage: _insertImage,
                                onInsertNoteLink: _insertNoteLink,
                                onOpenDoodleCanvas: _openDoodleCanvas,
                                onDeleteMediaBlock: _deleteMediaBlock,
                                checklistAttachments: _checklistAttachments,
                                checklistTitle: _title,
                                onUpdateChecklistTitle: _updateChecklistTitle,
                                onInsertChecklistImage: _note != null
                                    ? _insertChecklistImage
                                    : null,
                                onInsertChecklistDoodle: _note != null
                                    ? _insertChecklistDoodle
                                    : null,
                                onOpenChecklistAttachment: _note != null
                                    ? _openChecklistAttachment
                                    : null,
                                onDeleteChecklistAttachment: _note != null
                                    ? _deleteChecklistAttachment
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_note != null)
                        SliverToBoxAdapter(
                          child: BacklinksPanel(note: _note!),
                        ),
                    ],
                  ),

                  // 2. Auto-Hiding Glass App Bar (Zen Mode) or Focus Mode Toggle
                  if (!_focusMode)
                    AnimatedPositioned(
                      duration: AppMotion.medium3,
                      curve: AppMotion.emphasizedDecelerate,
                      top: isKeyboardVisible ? -100 : topPadding + 12,
                      left: 20,
                      right: 20,
                      child: RepaintBoundary(
                        child: AnimatedOpacity(
                          duration: AppMotion.short4,
                          opacity: isKeyboardVisible ? 0.0 : 1.0,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: Container(
                              height: 60,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: noteScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: ValueListenableBuilder<int>(
                                valueListenable: _undoRedoVersion,
                                builder: (context, _, __) =>
                                    ResponsiveEditorAppBar(
                                  noteScheme: noteScheme,
                                  dynamicTextTheme: dynamicTextTheme,
                                  title: _title,
                                  saving: _autosaveController.isSaving,
                                  isSaved: _showSavedFeedback,
                                  pinned: _pinned,
                                  note: _note,
                                  notebookName: _notebookName,
                                  tagNames: _tagNames,
                                  wordCount: _wordCount,
                                  readingTime: _readingTime,
                                  colorSeed: _colorSeed,
                                  onPickColor: _pickColor,
                                  onPickPaperStyle: _showPaperStyleSheet,
                                  onShowOutline: _showOutline,
                                  showFocusMode: !_focusMode,
                                  onEnterFocusMode: () {
                                    unawaited(HapticFeedback.selectionClick());
                                    setState(() => _focusMode = true);
                                  },
                                  onBack: () async {
                                    final router = GoRouter.of(context);
                                    unawaited(HapticFeedback.lightImpact());
                                    if (_autosaveController.isDirty) {
                                      if (_isEffectivelyEmpty() &&
                                          widget.noteId == null) {
                                        await NoteRepository(_db!)
                                            .permanentlyDelete(_note!.id);
                                      } else {
                                        await _save();
                                      }
                                    }
                                    if (mounted) router.pop();
                                  },
                                  onInsertImage:
                                      _readOnly ? null : _insertImage,
                                  onInsertDoodle:
                                      _readOnly ? null : _insertDoodle,
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
                    )
                  else
                    Positioned(
                      top: topPadding + 12,
                      right: 20,
                      child: IconButton.filledTonal(
                        tooltip: 'Exit focus mode',
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedViewOff,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() => _focusMode = false);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSystemBack() async {
    final router = GoRouter.of(context);
    unawaited(HapticFeedback.lightImpact());
    if (_autosaveController.isDirty) {
      if (_isEffectivelyEmpty() && widget.noteId == null) {
        await NoteRepository(_db!).permanentlyDelete(_note!.id);
        if (mounted) router.pop();
        return;
      } else {
        try {
          await _save();
        } catch (_) {}
        if (mounted) router.pop();
        return;
      }
    }
    router.pop();
  }
}
