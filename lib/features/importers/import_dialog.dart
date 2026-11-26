import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/haptics/haptics.dart';
import '../../core/providers/database_provider.dart';
import '../../data/repositories/note_repository.dart';
import '../editor/markdown_import.dart';
import '../settings/widgets/import_handler.dart';
import 'evernote_importer.dart';
import 'keep_importer.dart';
import 'notesnook_importer.dart';
import 'plain_text_importer.dart';

/// Shows a bottom sheet allowing users to import notes from external apps or formats.
Future<void> showImportNotesSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (modalContext) {
      final scheme = Theme.of(modalContext).colorScheme;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import Notes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bring your existing thoughts into Nook. Imported notes never overwrite existing data.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              _ImportOptionTile(
                icon: HugeIcons.strokeRoundedNote01,
                title: 'Google Keep',
                subtitle: 'Google Takeout Keep JSON files or .zip archive',
                onTap: () async {
                  Navigator.of(modalContext).pop();
                  await _importKeep(context, ref);
                },
              ),
              const SizedBox(height: 8),
              _ImportOptionTile(
                icon: HugeIcons.strokeRoundedNotebook,
                title: 'Evernote',
                subtitle: 'Exported .enex notebook files',
                onTap: () async {
                  Navigator.of(modalContext).pop();
                  await _importEvernote(context, ref);
                },
              ),
              const SizedBox(height: 8),
              _ImportOptionTile(
                icon: HugeIcons.strokeRoundedShield01,
                title: 'Notesnook',
                subtitle: 'Notesnook backup JSON or zip export',
                onTap: () async {
                  Navigator.of(modalContext).pop();
                  await _importNotesnook(context, ref);
                },
              ),
              const SizedBox(height: 8),
              _ImportOptionTile(
                icon: HugeIcons.strokeRoundedFile01,
                title: 'Markdown & Plain Text',
                subtitle: '.md, .markdown, or .txt files',
                onTap: () async {
                  Navigator.of(modalContext).pop();
                  await _importTextOrMarkdown(context, ref);
                },
              ),
              const SizedBox(height: 8),
              _ImportOptionTile(
                icon: HugeIcons.strokeRoundedFolder01,
                title: 'Nook Vault',
                subtitle: 'Encrypted or standard .nook backup archive',
                onTap: () async {
                  Navigator.of(modalContext).pop();
                  await _importNookVault(context, ref);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ImportOptionTile extends StatelessWidget {
  const _ImportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  icon: icon,
                  size: 22,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _importKeep(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'zip'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final db = ref.read(databaseProvider);
    final importer = KeepImporter(NoteRepository(db));
    var totalImported = 0;

    for (final f in picked.files) {
      if (f.path == null) continue;
      final file = File(f.path!);
      if (f.extension?.toLowerCase() == 'zip') {
        final bytes = await file.readAsBytes();
        final res = await importer.importZip(bytes);
        totalImported += res.notesImported;
      } else {
        final content = await file.readAsString();
        final res = await importer.importJson(content);
        totalImported += res.notesImported;
      }
    }

    if (!context.mounted) return;
    unawaited(AppHaptics.success());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $totalImported note(s) from Keep')),
    );
  } catch (e) {
    if (!context.mounted) return;
    unawaited(AppHaptics.error());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Keep import failed: $e')),
    );
  }
}

Future<void> _importEvernote(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['enex'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final files = [
      for (final f in picked.files)
        if (f.path != null) File(f.path!),
    ];

    final db = ref.read(databaseProvider);
    final importer = EvernoteImporter(NoteRepository(db));
    final res = await importer.importFiles(files);

    if (!context.mounted) return;
    unawaited(AppHaptics.success());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Imported ${res.notesImported} note(s) from Evernote')),
    );
  } catch (e) {
    if (!context.mounted) return;
    unawaited(AppHaptics.error());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Evernote import failed: $e')),
    );
  }
}

Future<void> _importNotesnook(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'zip'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final db = ref.read(databaseProvider);
    final importer = NotesnookImporter(NoteRepository(db));
    var totalImported = 0;

    for (final f in picked.files) {
      if (f.path == null) continue;
      final file = File(f.path!);
      if (f.extension?.toLowerCase() == 'zip') {
        final bytes = await file.readAsBytes();
        final res = await importer.importZip(bytes);
        totalImported += res.notesImported;
      } else {
        final content = await file.readAsString();
        final res = await importer.importJson(content);
        totalImported += res.notesImported;
      }
    }

    if (!context.mounted) return;
    unawaited(AppHaptics.success());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $totalImported note(s) from Notesnook')),
    );
  } catch (e) {
    if (!context.mounted) return;
    unawaited(AppHaptics.error());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notesnook import failed: $e')),
    );
  }
}

Future<void> _importTextOrMarkdown(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final files = [
      for (final f in picked.files)
        if (f.path != null) File(f.path!),
    ];

    final db = ref.read(databaseProvider);
    final mdFiles =
        files.where((f) => !f.path.toLowerCase().endsWith('.txt')).toList();
    final txtFiles =
        files.where((f) => f.path.toLowerCase().endsWith('.txt')).toList();

    var totalImported = 0;
    if (mdFiles.isNotEmpty) {
      final res =
          await MarkdownImporter(NoteRepository(db)).importFiles(mdFiles);
      totalImported += res.notesImported;
    }
    if (txtFiles.isNotEmpty) {
      final res =
          await PlainTextImporter(NoteRepository(db)).importFiles(txtFiles);
      totalImported += res.notesImported;
    }

    if (!context.mounted) return;
    unawaited(AppHaptics.success());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $totalImported note(s)')),
    );
  } catch (e) {
    if (!context.mounted) return;
    unawaited(AppHaptics.error());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Import failed: $e')),
    );
  }
}

Future<void> _importNookVault(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['nook'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    final db = ref.read(databaseProvider);
    final result = await NookImporter(database: db).importFrom(File(path));

    if (!context.mounted) return;
    unawaited(AppHaptics.success());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error ??
              'Imported ${result.notesImported} notes, ${result.attachmentsRestored} attachments',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    unawaited(AppHaptics.error());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vault import failed: $e')),
    );
  }
}
