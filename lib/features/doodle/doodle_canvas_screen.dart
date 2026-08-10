import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/doodle_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'doodle_controller.dart';
import 'doodle_canvas.dart';
import 'doodle_strokes_codec.dart';
import 'doodle_thumbnail_renderer.dart';
import 'doodle_toolbar.dart';

/// Full-screen doodle canvas for creating and editing doodles.
///
/// On completion, pops with the attachment id of the saved doodle.
class DoodleCanvasScreen extends ConsumerStatefulWidget {
  const DoodleCanvasScreen({
    super.key,
    required this.noteId,
    this.attachmentId,
    this.storage,
  });

  final String noteId;

  /// When set, the existing doodle is loaded for editing.
  final String? attachmentId;

  /// Injectable for tests; otherwise resolved from the documents directory.
  final DoodleStorage? storage;

  @override
  ConsumerState<DoodleCanvasScreen> createState() => _DoodleCanvasScreenState();
}

class _DoodleCanvasScreenState extends ConsumerState<DoodleCanvasScreen> {
  late final DoodleController _controller;

  DoodleStorage? _storage;

  @override
  void initState() {
    super.initState();
    _controller = DoodleController();
    _init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<DoodleStorage> _resolveStorage() async {
    final existing = _storage;
    if (existing != null) return existing;
    final storage = widget.storage ??
        DoodleStorage(
          attachments: AttachmentRepository(ref.read(databaseProvider)),
          baseDir: await getApplicationDocumentsDirectory(),
        );
    _storage = storage;
    return storage;
  }

  void _init() {
    _resolveStorage().then((storage) {
      final attachmentId = widget.attachmentId;
      if (attachmentId == null) return Future.value(const DoodleData());
      return storage.loadDoodle(attachmentId);
    }).then((data) {
      if (!mounted) return;
      _controller.replaceStrokes(data.strokes);
      _controller.setBackground(data.background);
    });
  }

  void _onDone() {
    _handleDone();
  }

  Future<void> _handleDone() async {
    final storage = _storage;
    if (storage == null) return;

    // Drift insert — safe in FakeAsync zone.
    final attachmentId = widget.attachmentId ??
        await storage.attachments
            .addDoodle(noteId: widget.noteId, filePath: '');

    if (!mounted) return;

    // Snapshot strokes before popping — pop triggers route disposal which
    // may dispose the controller, and _controller.strokes is a view, not a copy.
    final strokes = List<Stroke>.from(_controller.strokes);
    final background = _controller.background;

    // Pop immediately.  Do NOT block on dart:io file writes below.
    Navigator.of(context).pop(attachmentId);

    // Fire-and-forget: persist the doodle sidecar + thumbnail in the background.
    unawaited(_persistInBackground(storage, attachmentId, strokes, background));
  }

  /// Writes the strokes sidecar file and a thumbnail PNG, then updates the
  /// attachment row with the thumbnail path.
  Future<void> _persistInBackground(
    DoodleStorage storage,
    String attachmentId,
    List<Stroke> strokes,
    DoodleBackground background,
  ) async {
    try {
      await storage.saveDoodle(
        noteId: widget.noteId,
        strokes: strokes,
        background: background,
        attachmentId: attachmentId,
      );

      final thumbBytes = await DoodleThumbnailRenderer.render(
        strokes,
        background: background,
      );
      final baseDir = storage.baseDir;
      final thumbFile = await File('${baseDir.path}/${attachmentId}_thumb.png')
          .writeAsBytes(thumbBytes);
      await storage.attachments.updateThumbnail(attachmentId, thumbFile.path);
    } catch (_) {
      // Thumbnail generation is best-effort; don't crash on save.
    }
  }

  void _showBackgroundSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Background',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final option in DoodleBackground.values)
                ListTile(
                  title: Text(option.name.capitalize()),
                  trailing: option == _controller.background
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    _controller.setBackground(option);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // 1. Edge-to-Edge Canvas (Apple Notes style)
          Positioned.fill(
            child: DoodleCanvas(controller: _controller),
          ),

          // 2. Floating Top Action Bar
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _GlassButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onTap: () => Navigator.maybePop(context),
                ),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassButton(
                          icon: Icons.grid_view_rounded,
                          tooltip: 'Background',
                          onTap: () => _showBackgroundSheet(context),
                        ),
                        const SizedBox(width: 8),
                        _GlassButton(
                          icon: Icons.undo_rounded,
                          tooltip: 'Undo',
                          isEnabled: _controller.canUndo,
                          onTap: _controller.undo,
                        ),
                        const SizedBox(width: 8),
                        _GlassButton(
                          icon: Icons.redo_rounded,
                          tooltip: 'Redo',
                          isEnabled: _controller.canRedo,
                          onTap: _controller.redo,
                        ),
                      ],
                    );
                  },
                ),
                FilledButton(
                  onPressed: _onDone,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating Bottom Toolbar (Samsung/Apple Palette Style)
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            left: 0,
            right: 0,
            child: Center(
              child: DoodleToolbar(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.isEnabled = true,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isEnabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: tooltip,
      button: true,
      enabled: isEnabled,
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
          shape: const CircleBorder(),
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isEnabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                size: 22,
                color: isEnabled
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
