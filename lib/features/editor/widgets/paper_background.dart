import 'package:flutter/material.dart';

/// Available paper stationery background styles for notes.
enum NotePaperStyle {
  blank,
  ruled,
  grid,
  dotted,
}

/// Paints subtle analog paper textures behind note content.
class PaperBackgroundPainter extends CustomPainter {
  const PaperBackgroundPainter({
    required this.style,
    required this.color,
  });

  final NotePaperStyle style;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case NotePaperStyle.blank:
        break;
      case NotePaperStyle.ruled:
        final paint = Paint()
          ..color = color
          ..strokeWidth = 1.0;
        const spacing = 32.0;
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case NotePaperStyle.grid:
        final paint = Paint()
          ..color = color
          ..strokeWidth = 1.0;
        const spacing = 28.0;
        for (double x = spacing; x < size.width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
      case NotePaperStyle.dotted:
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
  }

  @override
  bool shouldRepaint(covariant PaperBackgroundPainter oldDelegate) =>
      oldDelegate.style != style || oldDelegate.color != color;
}
