import 'package:flutter/material.dart';

import 'doodle_controller.dart';

/// Full-screen drawing canvas that renders strokes via CustomPainter.
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
    return RepaintBoundary(
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
          painter: _StrokePainter(
            strokes: widget.controller.strokes,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Painter that renders all strokes.
class _StrokePainter extends CustomPainter {
  _StrokePainter({required this.strokes});

  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;

      final paint = Paint()
        ..color = stroke.color.withValues(alpha: stroke.opacity)
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = stroke.tool == DoodleTool.eraser
            ? PaintingStyle.stroke
            : PaintingStyle.stroke;

      if (stroke.tool == DoodleTool.eraser) {
        paint.blendMode = BlendMode.clear;
      }

      final path = Path();
      path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

      for (int i = 1; i < stroke.points.length; i++) {
        final p0 = stroke.points[i - 1];
        final p1 = stroke.points[i];
        final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      }

      // Draw the last point
      final last = stroke.points.last;
      path.lineTo(last.dx, last.dy);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) => true;
}
