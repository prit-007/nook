import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/nook_tokens.dart';
import 'backup_handler.dart';

/// UI for creating and restoring Argon2id-encrypted `.nookbackup` archives.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController();
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _createBackup() async {
    final pw = _passwordController.text;
    if (pw.isEmpty) {
      setState(() => _status = 'Enter a backup password first.');
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final db = ref.read(databaseProvider);
      final file = await BackupHandler(db).createEncryptedBackup(password: pw);
      if (!mounted) return;
      setState(() {
        _pathController.text = file.path;
        _status = 'Backup created: ${file.path}';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Backup failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final pw = _passwordController.text;
    final path = _pathController.text.trim();
    if (pw.isEmpty || path.isEmpty) {
      setState(() => _status = 'Enter both backup file path and password.');
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final db = ref.read(databaseProvider);
      final count = await BackupHandler(db).restoreEncryptedBackup(
        backupFile: File(path),
        password: pw,
      );
      if (!mounted) return;
      setState(() => _status = 'Restored $count note(s) from backup.');
    } catch (e) {
      if (mounted) setState(() => _status = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted Backup')),
      body: Padding(
        padding: const EdgeInsets.all(NookTokens.kSpacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Backups are encrypted with Argon2id + AES-256-GCM (.nookbackup).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: NookTokens.kSpacingLg),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Backup password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: NookTokens.kSpacingMd),
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'Backup file path (for restore)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: NookTokens.kSpacingLg),
            FilledButton.icon(
              onPressed: _busy ? null : _createBackup,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDownload01,
                size: 18,
              ),
              label: const Text('Create .nookbackup'),
            ),
            const SizedBox(height: NookTokens.kSpacingSm),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restoreBackup,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedUpload01,
                size: 18,
              ),
              label: const Text('Restore .nookbackup'),
            ),
            if (_status != null) ...[
              const SizedBox(height: NookTokens.kSpacingMd),
              Text(_status!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
