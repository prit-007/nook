import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';
import 'doodle/doodle_block.dart';
import 'widgets/custom_todo_list_block.dart';
import 'widgets/note_options_sheet.dart';

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

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _save();
    _editorState?.dispose();
    super.dispose();
  }

  Color _ambientBackgroundColor(BuildContext context) {
    if (_colorSeed != null && _colorSeed!.isNotEmpty) {
      final seed = Color(int.parse('0xFF${_colorSeed!.replaceFirst('#', '')}'));
      return ColorScheme.fromSeed(seedColor: seed)
          .surfaceContainerLow
          .withValues(alpha: 0.4);
    }
    return Theme.of(context).colorScheme.surface;
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

    return Scaffold(
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
                  onTap: () {
                    HapticFeedback.lightImpact();
                  },
                ),
              },
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
                      color:
                          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            color: scheme.onSurface,
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
                          child: Text(
                            _saving
                                ? 'Saving...'
                                : DateFormat('MMMM d, yyyy')
                                    .format(DateTime.now()),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _pinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            color: _pinned ? scheme.primary : scheme.onSurface,
                            size: 20,
                          ),
                          onPressed: _togglePin,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: scheme.onSurface,
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
    );
  }
}

class _FloatingFormatBar extends StatelessWidget {
  const _FloatingFormatBar({required this.editorState});

  final EditorState editorState;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
                  },
                ),
                _FormatAction(
                  icon: Icons.checklist_rounded,
                  onTap: () {
                    HapticFeedback.lightImpact();
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
    final scheme = Theme.of(context).colorScheme;
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
