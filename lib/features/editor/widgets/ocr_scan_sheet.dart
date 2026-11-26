import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/platform/ocr_service.dart';

/// Opens a sheet to pick an image, run offline FOSS OCR, review/edit the
/// recognized text, and return it for insertion into a note.
Future<String?> showOcrScanSheet(
  BuildContext context, {
  String? initialImagePath,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _OcrScanSheet(initialImagePath: initialImagePath),
  );
}

class _OcrScanSheet extends ConsumerStatefulWidget {
  const _OcrScanSheet({this.initialImagePath});

  final String? initialImagePath;

  @override
  ConsumerState<_OcrScanSheet> createState() => _OcrScanSheetState();
}

class _OcrScanSheetState extends ConsumerState<_OcrScanSheet> {
  final _textController = TextEditingController();
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      unawaited(_runOcr(widget.initialImagePath!));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null || !mounted) return;
    await _runOcr(file.path);
  }

  Future<void> _runOcr(String path) async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    final result = await ref.read(ocrServiceProvider).extractText(path);
    if (!mounted) return;
    setState(() {
      _scanning = false;
      if (result.isSuccess) {
        _textController.text = result.text;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedTextCheck,
                size: 22,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Scan text (offline OCR)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _scanning
                      ? null
                      : () => _pickAndScan(ImageSource.gallery),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedImage01,
                    size: 18,
                  ),
                  label: const Text('Choose image'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _scanning ? null : () => _pickAndScan(ImageSource.camera),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCamera01,
                    size: 18,
                  ),
                  label: const Text('Take photo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 13, color: scheme.error),
                ),
              ),
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Recognized text',
                hintText: 'Pick an image to extract text…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _scanning || _textController.text.trim().isEmpty
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context)
                              .pop(_textController.text.trim());
                        },
                  child: const Text('Insert Text'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
