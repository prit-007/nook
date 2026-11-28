import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tactile stationery surface pattern rendered subtly behind note content.
enum PaperPattern {
  none,
  dotted,
  ruled,
  graph,
}

/// Paints a subtle dot-grid, ruled-line, or graph-paper texture.
class PaperTexturePainter extends CustomPainter {
  const PaperTexturePainter({
    required this.pattern,
    required this.lineColor,
    this.spacing = 20.0,
  });

  final PaperPattern pattern;
  final Color lineColor;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    if (pattern == PaperPattern.none) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    switch (pattern) {
      case PaperPattern.none:
        return;
      case PaperPattern.dotted:
        final dotPaint = Paint()
          ..color = lineColor
          ..style = PaintingStyle.fill;
        for (double y = spacing; y < size.height; y += spacing) {
          for (double x = spacing; x < size.width; x += spacing) {
            canvas.drawCircle(Offset(x, y), 1.0, dotPaint);
          }
        }
      case PaperPattern.ruled:
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case PaperPattern.graph:
        for (double x = spacing; x < size.width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
    }
  }

  @override
  bool shouldRepaint(covariant PaperTexturePainter oldDelegate) {
    return oldDelegate.pattern != pattern ||
        oldDelegate.lineColor != lineColor ||
        (oldDelegate.spacing - spacing).abs() > math.pow(10, -6);
  }
}

/// Wraps [child] in a tactile paper-textured [CustomPaint] layer.
class PaperSurface extends StatelessWidget {
  const PaperSurface({
    super.key,
    required this.child,
    this.pattern = PaperPattern.dotted,
    this.spacing = 20.0,
    this.tint,
  });

  final Widget child;
  final PaperPattern pattern;
  final double spacing;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lineColor = (tint ?? scheme.outlineVariant).withValues(alpha: 0.22);

    return CustomPaint(
      painter: PaperTexturePainter(
        pattern: pattern,
        lineColor: lineColor,
        spacing: spacing,
      ),
      child: child,
    );
  }
}
