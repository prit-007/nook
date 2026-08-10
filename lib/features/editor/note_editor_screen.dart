import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/doodle_storage.dart';
import '../../data/repositories/note_repository.dart';
import '../../core/theme/note_theme_scope.dart';
import '../../data/tables/notes.dart';
import '../../features/doodle/doodle_canvas_screen.dart';
import '../../features/doodle/doodle_thumbnail_renderer.dart';
import 'doodle/doodle_block.dart';
import 'note_exporter.dart';
import 'widgets/custom_todo_list_block.dart';
import 'widgets/image_picker_handler.dart';
import 'widgets/note_options_sheet.dart';
import 'widgets/zoomable_image_block.dart';

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
  bool _loading = true;
  bool _saving = false;
  String? _colorSeed;
  String? _notebookId;
  Timer? _autosaveTimer;
  AppDatabase? _db;

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
      if (note == null) {
        if (mounted) context.pop();
        return;
      }
      _note = note;
      _title = note.title;
      _pinned = note.pinned;
      _colorSeed = note.colorSeed;
      _notebookId = note.notebookId;

      if (note.deltaContent != null && note.deltaContent!.isNotEmpty) {
        try {
          final json =
              Map<String, dynamic>.from(jsonDecode(note.deltaContent!) as Map);
          final document = Document.fromJson(json);
          _editorState = EditorState(document: document);
        } catch (e) {
          _editorState = EditorState.blank(withInitialText: true);
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
      _note = note;
      _editorState = EditorState.blank(withInitialText: true);
    }

    _editorState!.transactionStream.listen((_) {
      _scheduleAutosave();
    });

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    if (_note == null || _editorState == null || _saving) return;

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
        _title = derivedTitle;
        await repo.updateNote(_note!.id, title: _title);
      }

      await repo.updateContent(
        _note!.id,
        deltaContent: jsonEncode(_editorState!.document.toJson()),
        plainText: plainText,
      );
    } finally {
      _saving = false;
    }
  }

  Future<void> _togglePin() async {
    if (_note == null) return;
    // ignore: unawaited_futures
    HapticFeedback.lightImpact();
    final repo = NoteRepository(_db!);
    final newPinned = !_pinned;
    await repo.updateNote(_note!.id, pinned: newPinned);
    setState(() => _pinned = newPinned);
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
      onNotebookChanged: (id) async {
        _notebookId = id;
        await repo.updateNote(_note!.id, notebookId: id);
      },
      onColorChanged: (color) async {
        setState(() => _colorSeed = color);
        await repo.updateNote(_note!.id, colorSeed: color);
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

    // Insert an image node at the current cursor position.
    await _editorState!.insertImageNode(result.filePath);
    _scheduleAutosave();
  }

  /// Creates a new doodle block and opens the doodle canvas.
  Future<void> _insertDoodle() async {
    if (_note == null || _editorState == null) return;
    unawaited(HapticFeedback.lightImpact());

    final attachmentId = const Uuid().v4();

    // Insert a placeholder doodle node at the current cursor position.
    final node = doodleNode(attachmentId: attachmentId);
    final transaction = _editorState!.transaction;
    transaction.insertNode(_editorState!.document.root.path, node);
    await _editorState!.apply(transaction);

    // Open the canvas for the new doodle.
    await _openDoodleCanvas(node, _editorState!);
    _scheduleAutosave();
  }

  /// Exports the current note as a PNG and offers save-to-gallery / share.
  Future<void> _exportNote() async {
    if (_note == null || !mounted) return;
    unawaited(HapticFeedback.lightImpact());

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final boundaryKey = GlobalKey();

    // Build the render widget off-screen inside an Overlay.
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Material(
        color: Colors.transparent,
        child: RepaintBoundary(
          key: boundaryKey,
          child: _NoteExportCapture(note: _note!),
        ),
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
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Export failed: could not capture')),
        );
        return;
      }
      final bytes = await NoteExporter.captureBoundaryToPng(boundary);

      final baseDir = await getApplicationDocumentsDirectory();
      final filePath =
          '${baseDir.path}/${NoteExporter.generateFileName(_note!.title)}';
      await File(filePath).writeAsBytes(bytes);

      // Save to gallery
      await NoteExporter.saveToGallery(
        bytes,
        name: NoteExporter.generateFileName(_note!.title),
      );

      if (!mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Saved to gallery'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => NoteExporter.sharePng(filePath),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      entry.remove();
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
    final thumbBytes = await DoodleThumbnailRenderer.render(
      data.strokes,
      background: data.background,
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
    _autosaveTimer?.cancel();
    _save();
    _editorState?.dispose();
    super.dispose();
  }

  Color _ambientBackgroundColor(BuildContext context) {
    final noteScheme = _colorSeed != null && _colorSeed!.isNotEmpty
        ? ColorScheme.fromSeed(
            seedColor:
                Color(int.parse('0xFF${_colorSeed!.replaceFirst('#', '')}')),
          )
        : Theme.of(context).colorScheme;
    return noteScheme.surfaceContainerLow.withValues(alpha: 0.4);
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

    final noteScheme = _colorSeed != null && _colorSeed!.isNotEmpty
        ? ColorScheme.fromSeed(
            seedColor:
                Color(int.parse('0xFF${_colorSeed!.replaceFirst('#', '')}')),
          )
        : Theme.of(context).colorScheme;

    return NoteThemeScope(
      colorScheme: noteScheme,
      child: Scaffold(
        backgroundColor: _ambientBackgroundColor(context),
        body: Stack(
          children: [
            if (widget.noteId != null)
              Positioned.fill(
                child: Hero(
                  tag: 'note-${widget.noteId}',
                  child: ColoredBox(
                    color: _ambientBackgroundColor(context),
                  ),
                ),
              ),
            Positioned.fill(
              child: AppFlowyEditor(
                editorState: _editorState!,
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
                  ),
                  // Override the built-in image block with pinch-to-zoom support.
                  ImageBlockKeys.type: NookImageBlockComponentBuilder(),
                },
                characterShortcutEvents: [
                  ...standardCharacterShortcutEvents,
                  customSlashCommand(
                    [
                      ...standardSelectionMenuItems,
                      SelectionMenuItem(
                        getName: () => 'Doodle',
                        icon: (editorState, isSelected, style) =>
                            SelectionMenuIconWidget(
                          name: 'draw',
                          isSelected: isSelected,
                          style: style,
                        ),
                        keywords: ['doodle', 'draw', 'sketch'],
                        handler: (editorState, _, __) async {
                          final node = doodleNode(
                            attachmentId: const Uuid().v4(),
                          );
                          insertNodeAfterSelection(editorState, node);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: isKeyboardVisible ? -80 : topPadding + 12,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isKeyboardVisible ? 0.0 : 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: noteScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              noteScheme.outlineVariant.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: noteScheme.onSurface,
                            ),
                            onPressed: () async {
                              // ignore: unawaited_futures
                              HapticFeedback.lightImpact();
                              final nav = GoRouter.of(context);
                              await _save();
                              if (mounted) nav.pop();
                            },
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _title.isNotEmpty ? _title : 'Untitled',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: noteScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  _saving
                                      ? 'Saving...'
                                      : DateFormat('MMM d, yyyy')
                                          .format(DateTime.now()),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: noteScheme.onSurfaceVariant,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _pinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              color: _pinned
                                  ? noteScheme.primary
                                  : noteScheme.onSurface,
                              size: 20,
                            ),
                            onPressed: _togglePin,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.add_photo_alternate_rounded,
                              color: noteScheme.onSurface,
                              size: 20,
                            ),
                            onPressed: _insertImage,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.draw_rounded,
                              color: noteScheme.onSurface,
                              size: 20,
                            ),
                            onPressed: _insertDoodle,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.ios_share_rounded,
                              color: noteScheme.onSurface,
                              size: 20,
                            ),
                            onPressed: _exportNote,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              color: noteScheme.onSurface,
                            ),
                            onPressed: _showNoteOptions,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              bottom: isKeyboardVisible ? keyboardHeight + 16 : -100,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: isKeyboardVisible ? 1.0 : 0.0,
                  child: _FloatingFormatBar(editorState: _editorState!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingFormatBar extends StatelessWidget {
  const _FloatingFormatBar({required this.editorState});

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);

    return ExcludeFocus(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FormatAction(
                  icon: Icons.format_bold_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    editorState.toggleAttribute('bold');
                  },
                ),
                _FormatAction(
                  icon: Icons.format_italic_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    editorState.toggleAttribute('italic');
                  },
                ),
                _FormatAction(
                  icon: Icons.format_strikethrough_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    editorState.toggleAttribute('strikethrough');
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
                  onTap: () {
                    HapticFeedback.lightImpact();
                    insertNodeAfterSelection(
                      editorState,
                      bulletedListNode(),
                    );
                  },
                ),
                _FormatAction(
                  icon: Icons.checklist_rounded,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    insertNodeAfterSelection(
                      editorState,
                      todoListNode(checked: false),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatAction extends StatelessWidget {
  const _FormatAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = NoteThemeScope.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 22,
          color: scheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

/// Minimal capture-only widget for exporting a note as PNG.
class _NoteExportCapture extends StatelessWidget {
  const _NoteExportCapture({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMMM d, yyyy').format(note.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.black.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              note.title.isNotEmpty ? note.title : 'Untitled',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black,
                height: 1.2,
              ),
            ),
            if (note.plainText != null && note.plainText!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                note.plainText!,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF333333),
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Text(
              'nook',
              style: TextStyle(
                fontSize: 10,
                color: Colors.black.withValues(alpha: 0.2),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
