import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Exports a note's rendered content as a PNG image.
class NoteExporter {
  NoteExporter._();

  /// Converts a [ui.Image] to PNG bytes.
  static Future<Uint8List> imageToPng(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List() ?? Uint8List(0);
  }

  /// Captures a [RenderRepaintBoundary] as PNG bytes at [pixelRatio].
  static Future<Uint8List> captureBoundaryToPng(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 3.0,
  }) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await imageToPng(image);
    image.dispose();
    return bytes;
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

  /// Saves PNG [bytes] to the device gallery under the Nook album.
  ///
  /// Returns `true` if saved successfully.  Throws on permission denial.
  static Future<bool> saveToGallery(
    Uint8List bytes, {
    String name = 'nook-export',
  }) async {
    final hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      final granted = await Gal.requestAccess();
      if (!granted) return false;
    }
    await Gal.putImageBytes(bytes, name: name, album: 'Nook');
    return true;
  }

  /// Shares the PNG file at [filePath] via the platform share sheet.
  static Future<void> sharePng(String filePath) async {
    final params = ShareParams(files: [XFile(filePath)]);
    await SharePlus.instance.share(params);
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
