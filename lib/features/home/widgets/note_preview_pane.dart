import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/selection_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/database.dart';
import '../../../data/repositories/attachment_repository.dart';
import '../../../data/repositories/checklist_item_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/tables/attachments.dart';
import '../../../data/tables/notes.dart';

/// Right-hand pane of the tablet master-detail layout.
///
/// Shows a read-only preview of the note selected in the left-hand grid plus
/// an "Open in editor" action. On compact screens this widget is not used —
/// the route push flow handles navigation instead.
class NotePreviewPane extends ConsumerWidget {
  const NotePreviewPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteId = ref.watch(selectedNoteIdProvider);
    final scheme = Theme.of(context).colorScheme;

    if (noteId == null) {
      return const _PreviewPlaceholder(
        icon: HugeIcons.strokeRoundedCursorCircleSelection01,
        title: 'Select a note',
        subtitle: 'Choose a note from the list to preview it here.',
      );
    }

    final db = ref.watch(databaseProvider);
    return FutureBuilder(
      future: _loadNote(db, noteId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.$1 == null) {
          return const _PreviewPlaceholder(
            icon: HugeIcons.strokeRoundedFileQuestionMark,
            title: 'Note not found',
            subtitle: 'This note may have been deleted.',
          );
        }

        final note = data.$1!;
        final items = data.$2;
        final attachments = data.$3;
        final noteScheme = note.colorSeed != null && note.colorSeed!.isNotEmpty
            ? ColorScheme.fromSeed(
                seedColor: NookColors.parseHex(note.colorSeed),
                brightness: scheme.brightness,
              )
            : scheme;

        return ColoredBox(
          color: noteScheme.surfaceContainerLowest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PreviewHeader(
                noteId: note.id,
                title: note.title.isEmpty ? 'Untitled' : note.title,
                updatedAt: note.updatedAt,
                scheme: noteScheme,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (note.type != NoteType.checklist &&
                          note.plainText != null &&
                          note.plainText!.trim().isNotEmpty)
                        Text(
                          note.plainText!,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.65,
                            color: noteScheme.onSurface,
                          ),
                        ),
                      if (note.type != NoteType.checklist &&
                          note.plainText != null &&
                          note.plainText!.trim().isNotEmpty &&
                          items.isNotEmpty)
                        const SizedBox(height: 24),
                      if (items.isNotEmpty) ...[
                        Text(
                          'Checklist',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: noteScheme.primary.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final item in items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HugeIcon(
                                  icon: item.checked
                                      ? HugeIcons.strokeRoundedCheckmarkCircle01
                                      : HugeIcons.strokeRoundedCircle,
                                  size: 20,
                                  color: noteScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.itemText,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.4,
                                      color: noteScheme.onSurface,
                                      decoration: item.checked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      if (attachments.isNotEmpty) ...[
                        if (items.isNotEmpty ||
                            (note.plainText != null &&
                                note.plainText!.trim().isNotEmpty))
                          const SizedBox(height: 24),
                        Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: noteScheme.primary.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final attachment in attachments)
                              _AttachmentThumb(
                                attachment: attachment,
                                noteId: note.id,
                                scheme: noteScheme,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<(Note?, List<ChecklistItem>, List<Attachment>)> _loadNote(
    AppDatabase db,
    String noteId,
  ) async {
    final noteRepo = NoteRepository(db);
    final checklistRepo = ChecklistItemRepository(db);
    final attachmentRepo = AttachmentRepository(db);
    final note = await noteRepo.getNoteById(noteId);
    if (note == null) {
      return (null, const <ChecklistItem>[], const <Attachment>[]);
    }
    final items = await checklistRepo.getItems(noteId);
    final attachments = await attachmentRepo.getAllForNote(noteId);
    return (note, items, attachments);
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: EmptyState(
            icon: icon,
            title: title,
            subtitle: subtitle,
            animate: false,
          ),
        ),
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({
    required this.noteId,
    required this.title,
    required this.updatedAt,
    required this.scheme,
  });

  final String noteId;
  final String title;
  final DateTime updatedAt;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(updatedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/note/$noteId');
            },
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedExpand, size: 18),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '\u00b7 ${two(local.hour)}:${two(local.minute)}';
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({
    required this.attachment,
    required this.noteId,
    required this.scheme,
  });

  final Attachment attachment;
  final String noteId;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final file = File(attachment.filePath);
    final thumbnail = attachment.thumbnailPath != null &&
            File(attachment.thumbnailPath!).existsSync()
        ? attachment.thumbnailPath
        : null;

    final Widget child;
    if (thumbnail != null || file.existsSync()) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(thumbnail ?? file.path),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    } else {
      child = _fallback();
    }

    return Semantics(
      label: attachment.type == AttachmentType.doodleLayer
          ? 'Doodle attachment'
          : 'Image attachment',
      image: true,
      child: child,
    );
  }

  Widget _fallback() {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: HugeIcon(
        icon: attachment.type == AttachmentType.doodleLayer
            ? HugeIcons.strokeRoundedPenTool01
            : HugeIcons.strokeRoundedImage01,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
