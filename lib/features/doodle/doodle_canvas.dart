import 'package:flutter/material.dart';

import 'doodle_controller.dart';
import 'doodle_painter.dart';

/// Full-screen drawing canvas that renders organic, pressure-sensitive
/// strokes via perfect_freehand and a selectable background template.
///
/// Uses a [Listener] for raw pointer events (captures stylus pressure).
/// The [Listener] does not participate in the gesture arena, so the parent
/// scroll view can still handle 2-finger scrolling.
class DoodleCanvas extends StatefulWidget {
  const DoodleCanvas({
    super.key,
    required this.controller,
    this.boundaryKey,
    this.noteScheme,
  });

  final DoodleController controller;

  /// Key for the internal [RepaintBoundary] (used for thumbnail capture).
  final GlobalKey? boundaryKey;

  /// Optional note-specific color scheme for themed grid lines and background.
  final ColorScheme? noteScheme;

  @override
  State<DoodleCanvas> createState() => _DoodleCanvasState();
}

class _DoodleCanvasState extends State<DoodleCanvas> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(DoodleCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final noteScheme = widget.noteScheme;
    final background = widget.controller.background;

    return RepaintBoundary(
      key: widget.boundaryKey,
      child: CustomPaint(
        key: ValueKey('doodle-bg-${background.name}'),
        painter: _BackgroundPainter(
          background: background,
          color: (noteScheme?.outlineVariant ?? scheme.outlineVariant)
              .withValues(alpha: 0.3),
        ),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => widget.controller.startStroke(
            event.localPosition,
            pressure: event.pressure,
          ),
          onPointerMove: (event) => widget.controller.continueStroke(
            event.localPosition,
            pressure: event.pressure,
          ),
          onPointerUp: (_) => widget.controller.endStroke(),
          onPointerCancel: (_) => widget.controller.endStroke(),
          child: CustomPaint(
            painter: _StrokePainter(
              strokes: widget.controller.strokes,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

/// Renders the selected background template for the canvas.
class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({required this.background, required this.color});

  final DoodleBackground background;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    paintDoodleBackground(
      canvas,
      size,
      background: background,
      color: color,
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.background != background || oldDelegate.color != color;
  }
}

/// Uses perfect_freehand to render pressure-simulated strokes.
class _StrokePainter extends CustomPainter {
  _StrokePainter({required this.strokes});

  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    paintDoodleStrokes(canvas, size, strokes);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
