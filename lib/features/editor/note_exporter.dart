import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Exports a note's rendered content as a PNG image.
class NoteExporter {
  NoteExporter._();

  /// Converts a [ui.Image] to PNG bytes.
  static Future<Uint8List> imageToPng(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List() ?? Uint8List(0);
  }

  /// Saves a [ui.Image] as a PNG file at [filePath].
  static Future<String> saveImageToFile(
    ui.Image image, {
    required String filePath,
  }) async {
    final bytes = await imageToPng(image);
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  /// Generates a sanitized file name from a note [title].
  static String generateFileName(String title) {
    if (title.trim().isEmpty) {
      return 'note-${_timestamp()}.png';
    }

    var sanitized = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    if (sanitized.length > 80) {
      sanitized = sanitized.substring(0, 80);
    }

    return '$sanitized-${_timestamp()}.png';
  }

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }
}
