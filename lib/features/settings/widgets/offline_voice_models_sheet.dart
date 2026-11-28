import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path/path.dart' as p;

import '../../../core/platform/voice_capture_service.dart';
import '../../../core/theme/nook_tokens.dart';

/// Settings sheet for inspecting, importing (SHA-256 verified), and deleting
/// local offline speech-to-text model files.
class OfflineVoiceModelsSheet extends ConsumerStatefulWidget {
  const OfflineVoiceModelsSheet({super.key});

  @override
  ConsumerState<OfflineVoiceModelsSheet> createState() =>
      _OfflineVoiceModelsSheetState();
}

class _OfflineVoiceModelsSheetState
    extends ConsumerState<OfflineVoiceModelsSheet> {
  List<File> _models = const [];
  bool _loading = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mgr = ref.read(offlineVoiceModelManagerProvider);
    final models = await mgr.listModels();
    if (!mounted) return;
    setState(() {
      _models = models;
      _loading = false;
    });
  }

  Future<void> _importModel() async {
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.single.path == null || !mounted) return;
    final path = picked.files.single.path!;
    final hashController = TextEditingController();
    final hash = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Model SHA-256'),
        content: TextField(
          controller: hashController,
          decoration: const InputDecoration(
            hintText: 'Expected 64-char SHA-256 hex',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(hashController.text.trim()),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    hashController.dispose();
    if (hash == null || hash.isEmpty || !mounted) return;

    try {
      await ref.read(offlineVoiceModelManagerProvider).importModel(
            sourceFile: File(path),
            expectedSha256: hash,
          );
      if (!mounted) return;
      setState(() => _status = 'Model imported and verified.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Import failed: $e');
    }
  }

  Future<void> _deleteModel(File file) async {
    await ref
        .read(offlineVoiceModelManagerProvider)
        .deleteModel(p.basename(file.path));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(NookTokens.kSpacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedMic01,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: NookTokens.kSpacingSm),
              Text(
                'Offline Voice Models',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: NookTokens.kSpacingSm),
          if (_status != null) ...[
            Text(
              _status!,
              style: TextStyle(
                fontSize: NookTokens.kFontFloor,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: NookTokens.kSpacingSm),
          ],
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_models.isEmpty)
            Text(
              'No offline STT models imported yet.',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            for (final file in _models)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.basename(file.path)),
                trailing: IconButton(
                  tooltip: 'Delete model',
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete01,
                    size: 18,
                    color: scheme.error,
                  ),
                  onPressed: () => _deleteModel(file),
                ),
              ),
          const SizedBox(height: NookTokens.kSpacingMd),
          FilledButton.tonalIcon(
            onPressed: _importModel,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedDownload01,
              size: 18,
              color: scheme.onSecondaryContainer,
            ),
            label: const Text('Import Offline Model'),
          ),
        ],
      ),
    );
  }
}
