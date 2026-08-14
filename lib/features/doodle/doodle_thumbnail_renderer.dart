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
    paintDoodleStrokes(canvas, Size(width, height), strokes);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await NoteExporter.imageToPng(image);
    image.dispose();
    return bytes;
  }
}
