import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../features/editor/note_exporter.dart';
import 'doodle_controller.dart';
import 'doodle_painter.dart';

/// Renders a doodle's strokes + background to PNG bytes off-screen, for use as
/// an inline thumbnail in the editor.
class DoodleThumbnailRenderer {
  DoodleThumbnailRenderer._();

  static Future<Uint8List> render(
    List<Stroke> strokes, {
    DoodleBackground background = DoodleBackground.dotted,
    double width = 480,
    double height = 360,
    ColorScheme? noteScheme,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final surface = noteScheme?.surface ?? const Color(0xFFFFFFFF);
    canvas.drawRect(
      Offset.zero & Size(width, height),
      Paint()..color = surface,
    );

    final baseLineColor = noteScheme?.outlineVariant ??
        const Color(0xFF9E9E9E).withValues(alpha: 0.45);
    final lineColor = baseLineColor.computeLuminance() < 0.2
        ? Colors.white.withValues(alpha: 0.2)
        : baseLineColor.withValues(alpha: 0.3);
    paintDoodleBackground(
      canvas,
      Size(width, height),
      background: background,
      color: lineColor,
    );

    final hasPoints = strokes.any((s) => s.points.isNotEmpty);
    if (hasPoints) {
      double minX = double.infinity;
      double maxX = -double.infinity;
      double minY = double.infinity;
      double maxY = -double.infinity;

      for (final stroke in strokes) {
        for (final pt in stroke.points) {
          final x = pt.position.dx;
          final y = pt.position.dy;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }

      final strokeWidthMax = strokes.fold<double>(
        4.0,
        (maxW, s) => s.width > maxW ? s.width : maxW,
      );
      final padding = 24.0 + strokeWidthMax / 2;
      final contentW = (maxX - minX).clamp(1.0, double.infinity);
      final contentH = (maxY - minY).clamp(1.0, double.infinity);

      final availW = (width - 2 * padding).clamp(1.0, double.infinity);
      final availH = (height - 2 * padding).clamp(1.0, double.infinity);

      final scaleX = availW / contentW;
      final scaleY = availH / contentH;
      final scale = math.min(scaleX, scaleY).clamp(0.01, 1.2);

      final centerOffsetX = (width - contentW * scale) / 2 - minX * scale;
      final centerOffsetY = (height - contentH * scale) / 2 - minY * scale;

      canvas.save();
      canvas.translate(centerOffsetX, centerOffsetY);
      canvas.scale(scale);
      paintDoodleStrokes(canvas, Size(width, height), strokes);
      canvas.restore();
    } else {
      paintDoodleStrokes(canvas, Size(width, height), strokes);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await NoteExporter.imageToPng(image);
    image.dispose();
    return bytes;
  }
}
