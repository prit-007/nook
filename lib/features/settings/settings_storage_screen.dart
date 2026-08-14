import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/talker_provider.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/checklist_item_repository.dart';
import '../../data/repositories/note_repository.dart';
import 'providers/vault_stats_provider.dart';
import 'widgets/export_handler.dart';
import 'widgets/import_handler.dart';

/// Storage & Backup: live vault usage, `.nook` export + share, and import.
class SettingsStorageScreen extends ConsumerStatefulWidget {
  const SettingsStorageScreen({super.key});

  @override
  ConsumerState<SettingsStorageScreen> createState() =>
      _SettingsStorageScreenState();
}

class _SettingsStorageScreenState extends ConsumerState<SettingsStorageScreen> {
  bool _exporting = false;
  bool _importing = false;
  String? _resultMessage;

  Future<void> _exportVault() async {
    if (_exporting || _importing) return;
    nookLog(NookLogKey.database, 'Export started', LogLevel.debug);
    setState(() {
      _exporting = true;
      _resultMessage = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final path = await NookExporter(
        noteRepository: NoteRepository(db),
        checklistItemRepository: ChecklistItemRepository(db),
        attachmentRepository: AttachmentRepository(db),
      ).exportAll();

      if (!mounted) return;
      nookLog(NookLogKey.database, 'Export completed: $path', LogLevel.info);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault exported')),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: 'Nook vault export',
        ),
      );
    } catch (e) {
      nookLog(NookLogKey.database, 'Export failed: $e', LogLevel.error);
      if (mounted) {
        setState(() => _resultMessage = 'Export failed: $e');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importVault() async {
    if (_importing || _exporting) return;
    setState(() {
      _importing = true;
      _resultMessage = null;
    });

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['nook'],
      );
      final path = picked?.files.single.path;
      if (path == null) return;

      final confirmed = await _confirmImport();
      if (confirmed != true) return;

      final db = ref.read(databaseProvider);
      final result = await NookImporter(database: db).importFrom(File(path));

      if (!mounted) return;
      nookLog(
        NookLogKey.database,
        'Import completed: ${result.notesImported} notes, '
        '${result.attachmentsRestored} attachments',
        LogLevel.info,
      );
      setState(() {
        _resultMessage = result.error ??
            'Imported ${result.notesImported} '
                'note${result.notesImported == 1 ? '' : 's'}'
                '${result.duplicateNotes > 0 ? ' (${result.duplicateNotes} '
                    'kept as copies)' : ''}'
                ' \u00b7 ${result.attachmentsRestored} '
                'attachment${result.attachmentsRestored == 1 ? '' : 's'} '
                'restored';
      });
    } catch (e) {
      nookLog(NookLogKey.database, 'Import failed: $e', LogLevel.error);
      if (mounted) {
        setState(() => _resultMessage = 'Import failed: $e');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<bool?> _confirmImport() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import vault?'),
        content: const Text(
          'Imported notes never overwrite existing data — any note whose id '
          'already exists on this device is imported as a new copy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = ref.watch(vaultStatsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Storage & Backup',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          DockSafeArea.bottomOf(context) + 72,
        ),
        children: [
          const _SectionHeader(title: 'Vault Usage'),
          const SizedBox(height: 8),
          _GlassCard(
            child: stats.maybeWhen(
              orElse: () => const SizedBox.shrink(),
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Could not measure vault usage.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              data: (s) => Column(
                children: [
                  _StatRow(
                    icon: HugeIcons.strokeRoundedFile01,
                    label: 'Notes',
                    value: '${s.noteCount}',
                  ),
                  const Divider(height: 24),
                  _StatRow(
                    icon: HugeIcons.strokeRoundedImage01,
                    label: 'Attachments',
                    value: '${s.attachmentCount}',
                  ),
                  const Divider(height: 24),
                  _StatRow(
                    icon: HugeIcons.strokeRoundedDatabase,
                    label: 'Database',
                    value: formatBytes(s.dbBytes),
                  ),
                  const Divider(height: 24),
                  _StatRow(
                    icon: HugeIcons.strokeRoundedBrush,
                    label: 'Media & doodles',
                    value: formatBytes(s.mediaBytes),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionHeader(title: 'Backup'),
          const SizedBox(height: 8),
          _GlassCard(
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _exportVault();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _exporting
                                ? Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: scheme.onPrimaryContainer,
                                    ),
                                  )
                                : HugeIcon(
                                    icon: HugeIcons.strokeRoundedUpload01,
                                    size: 20,
                                    color: scheme.onPrimaryContainer,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _exporting
                                      ? 'Packaging your vault\u2026'
                                      : 'Export Vault',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Human-readable markdown + lossless '
                                  'JSON in a .nook zip, shared wherever '
                                  'you like.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowRight01,
                            size: 18,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _importVault();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _importing
                                ? Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: scheme.onPrimaryContainer,
                                    ),
                                  )
                                : HugeIcon(
                                    icon: HugeIcons.strokeRoundedDownload01,
                                    size: 20,
                                    color: scheme.onPrimaryContainer,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _importing
                                      ? 'Restoring vault\u2026'
                                      : 'Import .nook',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Restore a backup. Existing notes are '
                                  'never overwritten — id collisions '
                                  'become copies.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowRight01,
                            size: 18,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_resultMessage != null) ...[
            const SizedBox(height: 20),
            _ResultBanner(message: _resultMessage!),
          ],
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = message.startsWith('Import failed') ||
        message.startsWith('Export failed');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (failed ? scheme.errorContainer : scheme.secondaryContainer)
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: failed
                ? HugeIcons.strokeRoundedAlert01
                : HugeIcons.strokeRoundedCheckmarkCircle01,
            size: 20,
            color:
                failed ? scheme.onErrorContainer : scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: failed
                    ? scheme.onErrorContainer
                    : scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final dynamic icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 18, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: scheme.primary.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
