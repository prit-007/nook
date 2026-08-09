import 'package:flutter/material.dart';

import 'doodle_controller.dart';
import 'doodle_canvas.dart';
import 'doodle_toolbar.dart';

/// Full-screen doodle drawing mode (prompt #7).
/// Top bar: close, undo/redo, Done pill button.
/// Center: canvas with dotted-grid background.
/// Bottom: floating toolbar with tools, colors, width slider.
class DoodleCanvasScreen extends StatefulWidget {
  const DoodleCanvasScreen({
    super.key,
    required this.noteId,
    this.attachmentId,
  });

  final String noteId;
  final String? attachmentId;

  @override
  State<DoodleCanvasScreen> createState() => _DoodleCanvasScreenState();
}

class _DoodleCanvasScreenState extends State<DoodleCanvasScreen> {
  late final DoodleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DoodleController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          // ── Top bar ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      return Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.undo, size: 22),
                            onPressed:
                                _controller.canUndo ? _controller.undo : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.redo, size: 22),
                            onPressed:
                                _controller.canRedo ? _controller.redo : null,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () {
                      // TODO: save strokes to attachment
                      Navigator.maybePop(context);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),

          // ── Canvas area ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: DoodleCanvas(controller: _controller),
            ),
          ),

          // ── Toolbar ──
          DoodleToolbar(controller: _controller),
        ],
      ),
    );
  }
}
