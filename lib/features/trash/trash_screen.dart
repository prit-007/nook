import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/talker_provider.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/masked_reveal.dart';
import '../../core/widgets/masked_reveal_text.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/note_repository.dart';

/// Trash screen — high-contrast archive of deleted notes with glass dialogs.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  List<_DeletedNote> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = NoteRepository(db);
    final attachmentRepo = AttachmentRepository(db);
    final deleted = await repo.getDeletedNotes();
    if (!mounted) return;

    // Collect the soft-deleted attachments (deleted=true) for each note so the
    // archive shows their thumbnails, not just the note title. The files on
    // disk survive soft-delete, so only rows whose thumbnail still exists are
    // listed.
    final notes = <_DeletedNote>[];
    for (final n in deleted) {
      final attachments = await attachmentRepo.getDeletedForNote(n.id);
      final thumbnails = <String>[];
      for (final a in attachments) {
        final path = a.thumbnailPath ?? a.filePath;
        if (path.isNotEmpty && File(path).existsSync()) {
          thumbnails.add(path);
        }
      }
      notes.add(_DeletedNote(
        id: n.id,
        title: n.title,
        deletedAt: n.deletedAt,
        thumbnails: thumbnails,
      ));
    }

    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _restore(String id) async {
    unawaited(HapticFeedback.mediumImpact());
    nookLog(
        NookLogKey.database, 'Note restored from archive: $id', LogLevel.info);
    final db = ref.read(databaseProvider);
    final repo = NoteRepository(db);
    await repo.restore(id);
    await _load();
  }

  Future<void> _permanentDelete(String id, String title) async {
    unawaited(HapticFeedback.heavyImpact());
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Permanently Delete?',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          content: Text(
            '"$title" will be destroyed forever. This action cannot be undone.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Destroy',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      nookLog(
        NookLogKey.database,
        'Note destroyed forever: $id',
        LogLevel.warning,
      );
      final repo = NoteRepository(ref.read(databaseProvider));
      await repo.permanentlyDelete(id);
      await _load();
    }
  }

  Future<void> _emptyTrash() async {
    if (_notes.isEmpty) return;
    unawaited(HapticFeedback.heavyImpact());
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert01,
                  color: scheme.error,
                  size: 24),
              const SizedBox(width: 8),
              const Text(
                'Empty Archive?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          content: Text(
            'Permanently destroy all ${_notes.length} notes in the trash? '
            'This is absolute and irreversible.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Empty Trash',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      nookLog(
        NookLogKey.database,
        'Archive emptied (${_notes.length} notes destroyed)',
        LogLevel.warning,
      );
      final repo = NoteRepository(ref.read(databaseProvider));
      await repo.permanentlyDeleteAllDeleted();
      if (mounted) await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const MaskedRevealText(
          'Archive',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _notes.isEmpty
              ? const EmptyState(
                  icon: HugeIcons.strokeRoundedDelete01,
                  title: 'Archive is empty',
                  subtitle: 'Deleted notes will be held here',
                  animate: false,
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    DockSafeArea.bottomOf(context) + 80,
                  ),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final age = _formatAge(note.deletedAt);
                    return MaskedReveal(
                      delay: Duration(
                        milliseconds: (index * 50).clamp(0, 400),
                      ),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                        // Material keeps the ListTile's ink splash on top of
                        // the decorated background ("ink splashes invisible"
                        // framework warning).
                        child: Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: note.thumbnails.isEmpty
                                ? null
                                : _TrashThumbnail(
                                    path: note.thumbnails.first,
                                    extraCount: note.thumbnails.length - 1,
                                  ),
                            title: Text(
                              note.title.isEmpty
                                  ? 'Untitled Document'
                                  : note.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              note.thumbnails.isEmpty
                                  ? 'Archived $age'
                                  : 'Archived $age \u00b7 '
                                      '${note.thumbnails.length} '
                                      'attachment'
                                      '${note.thumbnails.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedUndo02,
                                    color: scheme.primary,
                                    size: 24,
                                  ),
                                  tooltip: 'Restore Note',
                                  onPressed: () => _restore(note.id),
                                ),
                                IconButton(
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedDelete01,
                                    color: scheme.error.withValues(alpha: 0.8),
                                    size: 24,
                                  ),
                                  tooltip: 'Destroy',
                                  onPressed: () =>
                                      _permanentDelete(note.id, note.title),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _notes.isNotEmpty
          ? Padding(
              padding: EdgeInsets.only(
                bottom: DockSafeArea.bottomOf(context) + 16,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: FloatingActionButton.extended(
                    backgroundColor:
                        scheme.errorContainer.withValues(alpha: 0.9),
                    foregroundColor: scheme.onErrorContainer,
                    elevation: 0,
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedFlameKindling,
                        size: 24,
                        color: scheme.onErrorContainer),
                    label: const Text(
                      'Empty Archive',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _emptyTrash,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  String _formatAge(DateTime? deletedAt) {
    if (deletedAt == null) return 'recently';
    final diff = DateTime.now().difference(deletedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

class _DeletedNote {
  const _DeletedNote({
    required this.id,
    required this.title,
    this.deletedAt,
    this.thumbnails = const [],
  });

  final String id;
  final String title;
  final DateTime? deletedAt;

  /// On-disk thumbnail paths of the note's soft-deleted attachments.
  final List<String> thumbnails;
}

/// Renders the first deleted attachment thumbnail with a "+N" badge when a
/// note has more media archived.
class _TrashThumbnail extends StatelessWidget {
  const _TrashThumbnail({required this.path, required this.extraCount});

  final String path;
  final int extraCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: scheme.surfaceContainerHighest,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedImage01,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (extraCount > 0)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.9,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    '+$extraCount',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
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
