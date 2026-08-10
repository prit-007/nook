import 'package:flutter/painting.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import 'doodle_controller.dart';

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

/// Paints a list of organic strokes onto [canvas].
void paintDoodleStrokes(Canvas canvas, Size size, List<Stroke> strokes) {
  for (final stroke in strokes) {
    if (stroke.points.isEmpty) continue;

    final paint = Paint()
      ..color = stroke.color.withValues(alpha: stroke.opacity)
      ..style = PaintingStyle.fill;

    if (stroke.tool == DoodleTool.eraser) {
      paint.blendMode = BlendMode.clear;
    }

    // 1. Map sampled points (with pressure) to perfect_freehand PointVectors
    final points = stroke.points
        .map((p) => PointVector(p.position.dx, p.position.dy, p.pressure))
        .toList();

    // 2. Generate the dynamic organic outline
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
