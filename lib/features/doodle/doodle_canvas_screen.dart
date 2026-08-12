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

  /// Track canvas height for "extend paper" feature.
  double _canvasHeightMultiplier = 1.0;

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

  Future<void> _handleDone() async {
    final storage = _storage;
    if (storage == null) return;

    final attachmentId = widget.attachmentId ??
        await storage.attachments
            .addDoodle(noteId: widget.noteId, filePath: '');

    if (!mounted) return;

    final strokes = List<Stroke>.from(_controller.strokes);
    final background = _controller.background;

    // Persist the strokes BEFORE popping so the caller (note editor) is
    // guaranteed to find the doodle file on disk when it re-loads it.
    // Thumbnail rendering is best-effort — the editor regenerates it anyway —
    // so a thumbnail failure must not block or lose the doodle.
    try {
      await storage.saveDoodle(
        noteId: widget.noteId,
        strokes: strokes,
        background: background,
        attachmentId: attachmentId,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save doodle. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(attachmentId);

    unawaited(_renderThumbnail(storage, attachmentId, strokes, background));
  }

  Future<void> _renderThumbnail(
    DoodleStorage storage,
    String attachmentId,
    List<Stroke> strokes,
    DoodleBackground background,
  ) async {
    try {
      final thumbBytes = await DoodleThumbnailRenderer.render(
        strokes,
        background: background,
      );
      final thumbFile =
          await File('${storage.baseDir.path}/${attachmentId}_thumb.png')
              .writeAsBytes(thumbBytes);
      await storage.attachments.updateThumbnail(attachmentId, thumbFile.path);
    } catch (_) {
      // Thumbnail generation is best-effort; don't crash on save.
    }
  }

  void _showBackgroundSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Canvas Paper Type',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final option in DoodleBackground.values)
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      title: Text(option.name.capitalize(),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: option == _controller.background
                          ? Icon(Icons.check_circle_rounded,
                              color: scheme.primary)
                          : null,
                      onTap: () {
                        _controller.setBackground(option);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
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
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final isDrawing = _controller.isDrawing;

          return Stack(
            children: [
              // 1. Interactive Scrollable Canvas (infinite vertical scroll)
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final baseHeight = MediaQuery.sizeOf(context).height;
                      return SizedBox(
                        height: baseHeight * _canvasHeightMultiplier,
                        child: Stack(
                          children: [
                            DoodleCanvas(controller: _controller),
                            // Extend Paper Trigger
                            Positioned(
                              bottom: 120,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: isDrawing ? 0.0 : 1.0,
                                  child: FilledButton.tonalIcon(
                                    icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded),
                                    label: const Text('Extend Paper'),
                                    onPressed: () {
                                      setState(() {
                                        _canvasHeightMultiplier += 0.5;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 2. Auto-Hiding Top Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                top: isDrawing ? -100 : MediaQuery.paddingOf(context).top + 16,
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
                    Row(
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
                    ),
                    FilledButton(
                      onPressed: _handleDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        elevation: 4,
                      ),
                      child: const Text('Done',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // 3. Auto-Hiding Bottom Dock
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                bottom: isDrawing
                    ? -120
                    : MediaQuery.paddingOf(context).bottom + 24,
                left: 0,
                right: 0,
                child: Center(
                  child: DoodleToolbar(controller: _controller),
                ),
              ),
            ],
          );
        },
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
