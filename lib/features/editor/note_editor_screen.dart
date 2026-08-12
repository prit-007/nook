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
import '../../core/theme/design_tokens.dart';
import '../../core/theme/note_theme_scope.dart';
import '../../data/database.dart';
import '../../data/repositories/attachment_repository.dart';
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

    // Insert an image node at the current cursor position.
    final node = imageNode(url: result.filePath);
    insertNodeAfterSelection(_editorState!, node);

    // Force an empty paragraph after the image so the user can keep typing.
    final pNode = paragraphNode();
    insertNodeAfterSelection(_editorState!, pNode);

    _scheduleAutosave();
  }

  /// Creates a new doodle block and opens the doodle canvas.
  Future<void> _insertDoodle() async {
    if (_note == null || _editorState == null) return;
    unawaited(HapticFeedback.lightImpact());

    final attachmentId = const Uuid().v4();

    // Insert a placeholder doodle node at the current cursor position.
    final node = doodleNode(attachmentId: attachmentId);
    insertNodeAfterSelection(_editorState!, node);

    // Force an empty paragraph after the doodle so the user can keep typing.
    final pNode = paragraphNode();
    insertNodeAfterSelection(_editorState!, pNode);

    // Open the canvas for the new doodle.
    await _openDoodleCanvas(node, _editorState!);
    _scheduleAutosave();
  }

  /// Exports the current note as a PNG and offers save-to-gallery / share.
  Future<void> _exportNote() async {
    if (_note == null || _editorState == null || !mounted) return;
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
          child: NoteExportCapture(
            note: _note!,
            editorState: _editorState!,
          ),
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
      final saved = await NoteExporter.saveToGallery(
        bytes,
        name: NoteExporter.generateFileName(_note!.title),
      );

      if (!mounted) return;
      scaffoldMessenger.hideCurrentSnackBar();
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
    _disposed = true;
    _autosaveTimer?.cancel();
    _transactionSubscription?.cancel();
    // Snapshot content synchronously before EditorState is disposed.
    final note = _note;
    final db = _db;
    if (note != null && db != null && _editorState != null) {
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

    final noteScheme = _colorSeed != null && _colorSeed!.isNotEmpty
        ? ColorScheme.fromSeed(
            seedColor: NookColors.parseHex(_colorSeed),
          )
        : Theme.of(context).colorScheme;

    final dynamicTextTheme =
        NoteThemeScope.buildDynamicTextTheme(context, noteScheme);

    return NoteThemeScope(
      colorScheme: noteScheme,
      textTheme: dynamicTextTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: noteScheme.surfaceContainerLowest,
        body: Stack(
          children: [
            if (widget.noteId != null)
              Positioned.fill(
                child: Hero(
                  tag: 'note-${widget.noteId}',
                  child: ColoredBox(color: noteScheme.surfaceContainerLowest),
                ),
              ),
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: topPadding + 90,
                    bottom: keyboardHeight + 120,
                  ),
                  sliver: SliverFillRemaining(
                    hasScrollBody: true,
                    child: AppFlowyEditor(
                      editorState: _editorState!,
                      editorStyle: EditorStyle.mobile(
                        cursorColor: noteScheme.primary,
                        selectionColor:
                            noteScheme.primary.withValues(alpha: 0.2),
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
                            padding: (_) =>
                                const EdgeInsets.symmetric(vertical: 24),
                          ),
                          onTap: (node, editorState) {
                            HapticFeedback.lightImpact();
                            _openDoodleCanvas(node, editorState);
                          },
                        ),
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
                          border: Border.all(
                            color: noteScheme.outlineVariant
                                .withValues(alpha: 0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: noteScheme.shadow.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
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
                            await _save();
                            if (mounted) router.pop();
                          },
                          onInsertImage: _insertImage,
                          onInsertDoodle: _insertDoodle,
                          onTogglePin: _togglePin,
                          onExport: _exportNote,
                          onMoreOptions: _showNoteOptions,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Floating Formatting Pill (Anchors to keyboard)
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
    );
  }
}

class _FloatingFormatBar extends StatelessWidget {
  const _FloatingFormatBar({required this.editorState});

  final EditorState editorState;

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
                    tooltip: 'Bold',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      editorState.toggleAttribute('bold');
                    },
                  ),
                  _FormatAction(
                    icon: Icons.format_italic_rounded,
                    tooltip: 'Italic',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      editorState.toggleAttribute('italic');
                    },
                  ),
                  _FormatAction(
                    icon: Icons.format_strikethrough_rounded,
                    tooltip: 'Strikethrough',
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
                    tooltip: 'Bullet list',
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
                    tooltip: 'Checklist',
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
      ),
    );
  }
}

class _FormatAction extends StatelessWidget {
  const _FormatAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

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
            color: scheme.onSurface.withValues(alpha: 0.8),
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
            if (isNarrow)
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
            else ...[
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
  });

  final Note note;
  final EditorState editorState;

  ColorScheme _noteScheme() {
    if (note.colorSeed != null && note.colorSeed!.isNotEmpty) {
      return ColorScheme.fromSeed(
        seedColor: NookColors.parseHex(note.colorSeed),
      );
    }
    return const ColorScheme.light();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _noteScheme();
    final nodes = editorState.document.root.children;

    return Material(
      color: scheme.surface,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
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
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.2,
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
            const SizedBox(height: 32),
            Text(
              'nook',
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                letterSpacing: 1.5,
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
