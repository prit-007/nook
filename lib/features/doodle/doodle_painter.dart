import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import 'doodle_controller.dart';
import 'doodle_shape_recognizer.dart';

/// Paints the background template for a [DoodleBackground].
void paintDoodleBackground(
  Canvas canvas,
  Size size, {
  required DoodleBackground background,
  required Color color,
}) {
  switch (background) {
    case DoodleBackground.blank:
      return;
    case DoodleBackground.dotted:
      _paintDots(canvas, size, alsoLines: false, color: color);
    case DoodleBackground.ruled:
      _paintLines(canvas, size, vertical: false, color: color);
    case DoodleBackground.graph:
      _paintDots(canvas, size, alsoLines: true, color: color);
      _paintLines(canvas, size, vertical: true, color: color);
  }
}

/// Paints a list of strokes onto [canvas].
///
/// Strokes flagged with [Stroke.isPerfectShape] are rendered as crisp
/// mathematical paths; all others go through perfect_freehand for organic
/// rendering. Arrows additionally get a drawn arrowhead at their end point.
void paintDoodleStrokes(Canvas canvas, Size size, List<Stroke> strokes) {
  for (final stroke in strokes) {
    if (stroke.points.isEmpty) continue;

    final paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.opacity);
    if (stroke.tool == DoodleTool.eraser) paint.blendMode = BlendMode.clear;

    if (stroke.isPerfectShape) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()
        ..moveTo(
            stroke.points.first.position.dx, stroke.points.first.position.dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].position.dx, stroke.points[i].position.dy);
      }
      canvas.drawPath(path, paint);

      if (stroke.shapeType == RecognizedShape.arrow &&
          stroke.points.length == 2) {
        _drawArrowhead(canvas, paint, stroke.points[0].position,
            stroke.points[1].position);
      }
      continue;
    }

    // Organic strokes via perfect_freehand.
    paint.style = PaintingStyle.fill;
    final points = stroke.points
        .map((p) => PointVector(p.position.dx, p.position.dy, p.pressure))
        .toList();
    final isPen = stroke.tool == DoodleTool.pen;
    final hasRealPressure = stroke.points.any((p) => p.pressure != 1.0);

    final outlinePoints = getStroke(
      points,
      options: StrokeOptions(
        size: stroke.width * 1.5,
        thinning: isPen ? 0.6 : 0.0,
        smoothing: 0.5,
        streamline: 0.5,
        simulatePressure: isPen ? !hasRealPressure : false,
        start: StrokeEndOptions.start(taperEnabled: isPen),
        end: StrokeEndOptions.end(taperEnabled: isPen),
      ),
    );
    if (outlinePoints.isEmpty) continue;

    final path = Path()..moveTo(outlinePoints.first.dx, outlinePoints.first.dy);
    for (int i = 1; i < outlinePoints.length; i++) {
      path.lineTo(outlinePoints[i].dx, outlinePoints[i].dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}

void _drawArrowhead(Canvas canvas, Paint linePaint, Offset from, Offset to) {
  const headLengthFraction = 0.18;
  const headAngle = 0.5; // radians, ~28.6°

  final shaft = to - from;
  final length = shaft.distance;
  if (length < 1) return;
  final headLength = (length * headLengthFraction).clamp(10.0, 28.0);
  final angle = shaft.direction;

  final leftPoint = to -
      Offset(
        headLength * math.cos(angle - headAngle),
        headLength * math.sin(angle - headAngle),
      );
  final rightPoint = to -
      Offset(
        headLength * math.cos(angle + headAngle),
        headLength * math.sin(angle + headAngle),
      );

  final fillPaint = Paint()
    ..color = linePaint.color
    ..style = PaintingStyle.fill;

  final headPath = Path()
    ..moveTo(to.dx, to.dy)
    ..lineTo(leftPoint.dx, leftPoint.dy)
    ..lineTo(rightPoint.dx, rightPoint.dy)
    ..close();
  canvas.drawPath(headPath, fillPaint);
}

void _paintDots(
  Canvas canvas,
  Size size, {
  required bool alsoLines,
  required Color color,
}) {
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

  if (alsoLines) {
    _paintLines(canvas, size, vertical: true, color: color);
  }
}

void _paintLines(
  Canvas canvas,
  Size size, {
  required bool vertical,
  required Color color,
}) {
  final paint = Paint()
    ..color = color
    ..strokeWidth = 1.0;

  const spacing = 28.0;

  if (vertical) {
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  } else {
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
}
