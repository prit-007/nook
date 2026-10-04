import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../core/providers/database_provider.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../data/database.dart';
import '../../data/repositories/revision_repository.dart';

/// Lists local version-history snapshots for a note; tap to restore.
class VersionHistoryScreen extends ConsumerStatefulWidget {
  const VersionHistoryScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<VersionHistoryScreen> createState() =>
      _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends ConsumerState<VersionHistoryScreen> {
  List<NoteRevision> _revisions = [];
  bool _loading = true;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final revisions = await RevisionRepository(db).listForNote(widget.noteId);
    if (!mounted) return;
    setState(() {
      _revisions = revisions;
      _loading = false;
    });
  }

  Future<void> _restore(NoteRevision revision) async {
    if (_restoring) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this version?'),
        content: const Text(
          'The current note will be saved as a new version first, then this '
          'snapshot is applied.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _restoring = true);
    try {
      final db = ref.read(databaseProvider);
      await RevisionRepository(db).restore(revision.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Version restored')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y · h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Version history',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01, size: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _revisions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No versions yet.\nVersions are saved automatically as '
                      'you edit.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    DockSafeArea.bottomOf(context) + 16,
                  ),
                  itemCount: _revisions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final rev = _revisions[index];
                    final preview = (rev.plainText ?? rev.title).trim();
                    final previewText = preview.isEmpty
                        ? 'Empty note'
                        : preview.length > 120
                            ? '${preview.substring(0, 120)}…'
                            : preview;
                    return Material(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _restoring ? null : () => _restore(rev),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatWhen(rev.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: scheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      rev.source,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: scheme.onSecondaryContainer,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                rev.title.isEmpty ? 'Untitled' : rev.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                previewText,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to restore',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: scheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
