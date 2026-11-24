import 'dart:async';
import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/theme/note_theme.dart';
import '../../core/theme/note_theme_scope.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import 'doodle/doodle_block.dart';
import 'widgets/color_picker_sheet.dart';
import 'widgets/note_options_sheet.dart';
import 'widgets/paper_background.dart';

export 'widgets/paper_background.dart' show NotePaperStyle;

/// Bottom sheet showing a preview of the exported PNG with share/save actions.
class ExportPreviewSheet extends StatelessWidget {
  const ExportPreviewSheet({
    super.key,
    required this.bytes,
    required this.noteTitle,
  });

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
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedShare01,
                    size: 18,
                    color: scheme.onSurface,
                  ),
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
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedDownload01,
                    size: 18,
                    color: scheme.onSurface,
                  ),
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
                fontSize: 12,
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
                      HugeIcon(
                        icon: checked
                            ? HugeIcons.strokeRoundedCheckmarkCircle01
                            : HugeIcons.strokeRoundedCircle,
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
                      HugeIcon(
                        icon: item.checked
                            ? HugeIcons.strokeRoundedCheckmarkCircle01
                            : HugeIcons.strokeRoundedCircle,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'nook.',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary.withValues(alpha: 0.4),
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  DateFormat('yyyy').format(note.updatedAt),
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a modal bottom sheet to select a paper background texture.
Future<NotePaperStyle?> showPaperStyleSheet(
  BuildContext context, {
  required NotePaperStyle currentStyle,
}) async {
  unawaited(HapticFeedback.selectionClick());
  final scheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<NotePaperStyle>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 16),
                Text(
                  'Paper Style',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose stationery background texture',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                for (final style in NotePaperStyle.values)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: HugeIcon(
                      icon: switch (style) {
                        NotePaperStyle.blank => HugeIcons.strokeRoundedFile01,
                        NotePaperStyle.ruled => HugeIcons.strokeRoundedMenu01,
                        NotePaperStyle.grid => HugeIcons.strokeRoundedGrid,
                        NotePaperStyle.dotted => HugeIcons.strokeRoundedCircle,
                      },
                      color: currentStyle == style
                          ? scheme.primary
                          : scheme.onSurface,
                    ),
                    title: Text(
                      switch (style) {
                        NotePaperStyle.blank => 'Blank (Clean)',
                        NotePaperStyle.ruled => 'Ruled (Lined)',
                        NotePaperStyle.grid => 'Grid (Graph)',
                        NotePaperStyle.dotted => 'Dotted (Bullet)',
                      },
                      style: TextStyle(
                        fontWeight: currentStyle == style
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: currentStyle == style ? scheme.primary : null,
                      ),
                    ),
                    trailing: currentStyle == style
                        ? HugeIcon(
                            icon: HugeIcons.strokeRoundedTick02,
                            color: scheme.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      Navigator.of(context).pop(style);
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Helper to pick a note color seed and persist it to the database.
Future<String?> pickEditorColor({
  required BuildContext context,
  required AppDatabase db,
  required Note note,
  required String? currentColorSeed,
}) async {
  unawaited(HapticFeedback.selectionClick());
  final newSeed = await ColorPickerSheet.show(
    context,
    currentSeed: currentColorSeed,
  );
  if (newSeed == null) return null;
  unawaited(HapticFeedback.mediumImpact());
  await NoteRepository(db).updateNote(
    note.id,
    colorSeed: newSeed.isEmpty ? '' : newSeed,
  );
  return newSeed.isEmpty ? null : newSeed;
}

/// Helper to display note options sheet (notebook, tags, locking, color,
/// typography).
Future<void> showEditorNoteOptions({
  required BuildContext context,
  required AppDatabase db,
  required Note note,
  required String? currentNotebookId,
  required String? currentColorSeed,
  required NoteFontStyle currentFontStyle,
  required bool currentReadOnly,
  required bool currentlyLocked,
  required Future<void> Function(String? notebookId) onNotebookChanged,
  required void Function(String? colorSeed) onColorChanged,
  required void Function(NoteFontStyle fontStyle) onFontStyleChanged,
  required void Function(bool readOnly) onReadOnlyChanged,
  required Future<void> Function(List<String> tagIds) onTagsChanged,
  required void Function(bool locked) onLockedChanged,
}) async {
  unawaited(HapticFeedback.selectionClick());
  final repo = NoteRepository(db);

  await NoteOptionsSheet.show(
    context,
    noteId: note.id,
    currentNotebookId: currentNotebookId,
    currentColorSeed: currentColorSeed,
    currentFontStyle: currentFontStyle,
    currentReadOnly: currentReadOnly,
    currentlyLocked: currentlyLocked,
    onNotebookChanged: onNotebookChanged,
    onColorChanged: (color) async {
      onColorChanged(color);
      await repo.updateNote(note.id, colorSeed: color);
    },
    onFontStyleChanged: (style) async {
      onFontStyleChanged(style);
      await repo.updateNote(note.id, fontStyle: style);
    },
    onReadOnlyChanged: (readOnly) async {
      onReadOnlyChanged(readOnly);
    },
    onTagsChanged: onTagsChanged,
    onLockedChanged: (locked) async {
      if (locked) {
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
      onLockedChanged(locked);
      await repo.updateNote(note.id, locked: locked);
    },
  );
}
