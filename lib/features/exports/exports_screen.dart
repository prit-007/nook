import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/widgets/dock_safe_area.dart';
import 'exports_directory.dart';
import 'exports_repository.dart';

/// Browse, open, share, and delete files in the Nook exports folder.
class ExportsScreen extends StatefulWidget {
  const ExportsScreen({super.key, this.repository});

  /// Injectable for tests; production resolves [ExportsDirectory].
  final ExportsRepository? repository;

  @override
  State<ExportsScreen> createState() => _ExportsScreenState();
}

class _ExportsScreenState extends State<ExportsScreen> {
  ExportsRepository? _repo;
  List<ExportEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final repo = widget.repository ??
          ExportsRepository(await ExportsDirectory.resolve());
      final entries = await repo.list();
      if (!mounted) return;
      setState(() {
        _repo = repo;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final repo = _repo;
    if (repo == null) return;
    final entries = await repo.list();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _share(ExportEntry entry) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(entry.path)],
          subject: entry.name,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _open(ExportEntry entry) async {
    final result = await OpenFilex.open(entry.path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open ${entry.name}')),
      );
    }
  }

  Future<void> _delete(ExportEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete export?'),
        content: Text('Remove “${entry.name}” from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || _repo == null) return;
    await _repo!.delete(entry.path);
    await _refresh();
  }

  List<List<dynamic>> _iconFor(ExportEntry entry) {
    if (entry.isImage) return HugeIcons.strokeRoundedImage01;
    if (entry.format == ExportFormat.html) {
      return HugeIcons.strokeRoundedCode;
    }
    return HugeIcons.strokeRoundedFile01;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Exports',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh01, size: 22),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load exports\n$_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : _entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedDownload01,
                              size: 48,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No exports yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vault backups, Markdown/HTML zips, and note '
                              'PNGs saved from Nook appear here.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
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
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return Material(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: HugeIcon(
                                icon: _iconFor(entry),
                                size: 20,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                            title: Text(
                              entry.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${entry.format.label} · '
                              '${ExportsRepository.formatSize(entry.sizeBytes)}\n'
                              'Created ${ExportsRepository.formatDate(entry.createdAt)}'
                              ' · Modified ${ExportsRepository.formatDate(entry.modifiedAt)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedMoreVertical,
                                size: 20,
                              ),
                              onSelected: (action) {
                                unawaited(HapticFeedback.lightImpact());
                                switch (action) {
                                  case 'open':
                                    unawaited(_open(entry));
                                  case 'share':
                                    unawaited(_share(entry));
                                  case 'delete':
                                    unawaited(_delete(entry));
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'open',
                                  child: Text('Open'),
                                ),
                                const PopupMenuItem(
                                  value: 'share',
                                  child: Text('Share'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(color: scheme.error),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => unawaited(_open(entry)),
                          ),
                        );
                      },
                    ),
    );
  }
}
