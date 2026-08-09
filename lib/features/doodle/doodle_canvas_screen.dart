import 'package:flutter/material.dart';

import 'doodle_controller.dart';
import 'doodle_canvas.dart';
import 'doodle_toolbar.dart';

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
                  onTap: () => Navigator.maybePop(context),
                ),
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GlassButton(
                          icon: Icons.undo_rounded,
                          isEnabled: _controller.canUndo,
                          onTap: _controller.undo,
                        ),
                        const SizedBox(width: 8),
                        _GlassButton(
                          icon: Icons.redo_rounded,
                          isEnabled: _controller.canRedo,
                          onTap: _controller.redo,
                        ),
                      ],
                    );
                  },
                ),
                FilledButton(
                  onPressed: () {
                    // TODO: save strokes to attachment
                    Navigator.maybePop(context);
                  },
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
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
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
    );
  }
}
