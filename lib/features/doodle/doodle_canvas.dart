import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import 'doodle_controller.dart';

/// Full-screen drawing canvas that renders organic, pressure-sensitive
/// strokes via perfect_freehand and a custom dot-grid background.
class DoodleCanvas extends StatefulWidget {
  const DoodleCanvas({super.key, required this.controller});

  final DoodleController controller;

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

    return RepaintBoundary(
      child: CustomPaint(
        // The background dot-grid
        painter: _DotGridPainter(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
        child: GestureDetector(
          onPanStart: (details) {
            widget.controller.startStroke(details.localPosition);
          },
          onPanUpdate: (details) {
            widget.controller.continueStroke(details.localPosition);
          },
          onPanEnd: (_) {
            widget.controller.endStroke();
          },
          child: CustomPaint(
            // The organic strokes
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

/// Renders a premium, subtle dot-grid background (similar to physical notebooks).
class _DotGridPainter extends CustomPainter {
  _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const radius = 1.2;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Uses perfect_freehand to render pressure-simulated strokes.
class _StrokePainter extends CustomPainter {
  _StrokePainter({required this.strokes});

  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity)
        ..style = PaintingStyle.fill;

      if (stroke.tool == DoodleTool.eraser) {
        paint.blendMode = BlendMode.clear;
      }

      // 1. Map standard Flutter Offsets to perfect_freehand PointVectors
      final points = stroke.points.map((p) => PointVector(p.dx, p.dy)).toList();

      // 2. Generate the dynamic organic outline
      final isPen = stroke.tool == DoodleTool.pen;

      final outlinePoints = getStroke(
        points,
        options: StrokeOptions(
          size: stroke.width * 1.5,
          thinning: isPen ? 0.6 : 0.0,
          smoothing: 0.5,
          streamline: 0.5,
          simulatePressure: isPen,
          start: StrokeEndOptions.start(taperEnabled: isPen),
          end: StrokeEndOptions.end(taperEnabled: isPen),
        ),
      );

      if (outlinePoints.isEmpty) continue;

      // 3. Convert the resulting outline back into a Flutter Path
      final path = Path();
      path.moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
      for (int i = 1; i < outlinePoints.length; i++) {
        path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
      }
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
