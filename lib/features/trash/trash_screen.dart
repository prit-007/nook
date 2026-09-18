import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/talker_provider.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/masked_reveal_text.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/notebook_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/tables/attachments.dart';

/// Bin screen — archived notes, notebooks, tags and attachments with four
/// categorized tabs.
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<DeletedItem> _notes = [];
  List<DeletedItem> _notebooks = [];
  List<DeletedItem> _tags = [];
  List<DeletedItem> _attachments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _totalCount =>
      _notes.length + _notebooks.length + _tags.length + _attachments.length;

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final noteRepo = NoteRepository(db);
    final notebookRepo = NotebookRepository(db);
    final tagRepo = TagRepository(db);
    final attachmentRepo = AttachmentRepository(db);

    final deletedNotes = await noteRepo.getDeletedNotes();
    final deletedNotebooks = await notebookRepo.getDeletedNotebooks();
    final deletedTags = await tagRepo.getDeletedTags();
    final deletedAttachments = await attachmentRepo.getDeletedAttachments();
    if (!mounted) return;

    setState(() {
      _notes = deletedNotes
          .map((n) => DeletedItem(
                id: n.id,
                name: n.title.isEmpty ? 'Untitled Document' : n.title,
                deletedAt: n.deletedAt,
                type: DeletedItemType.note,
              ))
          .toList();
      _notebooks = deletedNotebooks
          .map((n) => DeletedItem(
                id: n.id,
                name: n.name,
                deletedAt: n.deletedAt,
                type: DeletedItemType.notebook,
              ))
          .toList();
      _tags = deletedTags
          .map((t) => DeletedItem(
                id: t.id,
                name: t.name,
                deletedAt: t.deletedAt,
                type: DeletedItemType.tag,
              ))
          .toList();
      _attachments = deletedAttachments
          .map((a) => DeletedItem(
                id: a.id,
                name: _attachmentLabel(a),
                deletedAt: a.deletedAt,
                type: DeletedItemType.attachment,
                filePath: a.filePath,
              ))
          .toList();
      _loading = false;
    });
  }

  String _attachmentLabel(dynamic a) {
    final type = a.type;
    if (type == AttachmentType.image) return 'Image attachment';
    if (type == AttachmentType.doodleLayer) return 'Doodle attachment';
    return 'Attachment';
  }

  Future<void> _restore(DeletedItem item) async {
    unawaited(HapticFeedback.mediumImpact());
    nookLog(NookLogKey.database,
        'Item restored from bin: ${item.name} (${item.id})', LogLevel.info);
    final db = ref.read(databaseProvider);
    switch (item.type) {
      case DeletedItemType.note:
        await NoteRepository(db).restore(item.id);
      case DeletedItemType.notebook:
        await NotebookRepository(db).restore(item.id);
      case DeletedItemType.tag:
        await TagRepository(db).restore(item.id);
      case DeletedItemType.attachment:
        await AttachmentRepository(db).restore(item.id);
    }
    await _load();
  }

  Future<void> _permanentDelete(DeletedItem item) async {
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
            '"${item.name}" will be destroyed forever. This action cannot be undone.',
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
          'Item destroyed forever: ${item.name} (${item.id})',
          LogLevel.warning);
      final db = ref.read(databaseProvider);
      switch (item.type) {
        case DeletedItemType.note:
          await NoteRepository(db).permanentlyDelete(item.id);
        case DeletedItemType.notebook:
          await NotebookRepository(db).permanentlyDelete(item.id);
        case DeletedItemType.tag:
          await TagRepository(db).permanentlyDelete(item.id);
        case DeletedItemType.attachment:
          await AttachmentRepository(db).permanentlyDeleteWithFiles(
            (await AttachmentRepository(db).getDeletedAttachments())
                .firstWhere((a) => a.id == item.id),
          );
      }
      await _load();
    }
  }

  Future<void> _emptyBin() async {
    if (_totalCount == 0) return;
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
                'Empty Bin?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          content: Text(
            'Permanently destroy all $_totalCount items in the bin? '
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
                'Empty Bin',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      nookLog(NookLogKey.database, 'Bin emptied ($_totalCount items destroyed)',
          LogLevel.warning);
      final db = ref.read(databaseProvider);
      await Future.wait([
        NoteRepository(db).permanentlyDeleteAllDeleted(),
        NotebookRepository(db).permanentlyDeleteAllDeleted(),
        TagRepository(db).permanentlyDeleteAllDeleted(),
        AttachmentRepository(db).permanentlyDeleteAllDeleted(),
      ]);
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
          'Bin',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Notes'),
            Tab(text: 'Notebooks'),
            Tab(text: 'Tags'),
            Tab(text: 'Attachments'),
          ],
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _BinTab(
                  items: _notes,
                  onRestore: _restore,
                  onDestroy: _permanentDelete,
                  emptyTitle: 'No deleted notes',
                  emptySubtitle: 'Deleted notes will appear here',
                ),
                _BinTab(
                  items: _notebooks,
                  onRestore: _restore,
                  onDestroy: _permanentDelete,
                  emptyTitle: 'No deleted notebooks',
                  emptySubtitle: 'Deleted notebooks will appear here',
                ),
                _BinTab(
                  items: _tags,
                  onRestore: _restore,
                  onDestroy: _permanentDelete,
                  emptyTitle: 'No deleted tags',
                  emptySubtitle: 'Deleted tags will appear here',
                ),
                _BinTab(
                  items: _attachments,
                  onRestore: _restore,
                  onDestroy: _permanentDelete,
                  emptyTitle: 'No deleted attachments',
                  emptySubtitle: 'Deleted attachments will appear here',
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _totalCount > 0
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
                      'Empty Bin',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _emptyBin,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

enum DeletedItemType { note, notebook, tag, attachment }

class DeletedItem {
  const DeletedItem({
    required this.id,
    required this.name,
    required this.type,
    this.deletedAt,
    this.filePath,
  });

  final String id;
  final String name;
  final DeletedItemType type;
  final DateTime? deletedAt;
  final String? filePath;
}

/// Shared widget for a single tab in the Bin screen.
class _BinTab extends StatelessWidget {
  const _BinTab({
    required this.items,
    required this.onRestore,
    required this.onDestroy,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<DeletedItem> items;
  final Future<void> Function(DeletedItem) onRestore;
  final Future<void> Function(DeletedItem) onDestroy;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedDelete01,
                size: 48,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'Nothing here yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        DockSafeArea.bottomOf(context) + 80,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final age = _formatAge(item.deletedAt);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: _itemIcon(item, scheme),
              title: Text(
                item.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'Archived $age',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
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
                    tooltip: 'Restore',
                    onPressed: () => onRestore(item),
                  ),
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedDelete01,
                      color: scheme.error.withValues(alpha: 0.8),
                      size: 24,
                    ),
                    tooltip: 'Destroy',
                    onPressed: () => onDestroy(item),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget? _itemIcon(DeletedItem item, ColorScheme scheme) {
    final iconData = switch (item.type) {
      DeletedItemType.note => HugeIcons.strokeRoundedNote01,
      DeletedItemType.notebook => HugeIcons.strokeRoundedNotebook01,
      DeletedItemType.tag => HugeIcons.strokeRoundedTag01,
      DeletedItemType.attachment => HugeIcons.strokeRoundedImage01,
    };
    return HugeIcon(
      icon: iconData,
      size: 24,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
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
