import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// Distinguishable export failure reasons for better user feedback.
enum ExportFailure {
  permissionDenied,
  fileNotFound,
  unknown,
}

/// Result of an export operation.
class ExportResult {
  const ExportResult.success() : failure = null;
  const ExportResult.failure(this.failure);

  final ExportFailure? failure;
  bool get isSuccess => failure == null;

  String get message {
    switch (failure) {
      case ExportFailure.permissionDenied:
        return 'Enable photo access in Settings to save exports.';
      case ExportFailure.fileNotFound:
        return 'Export file could not be created.';
      case ExportFailure.unknown:
        return 'Export failed. Please try again.';
      case null:
        return 'Exported successfully.';
    }
  }
}

/// Exports a note's rendered content as a PNG image.
class NoteExporter {
  NoteExporter._();

  /// Maximum dimension (width or height) before downscaling. Prevents
  /// multi-megabyte PNGs for very long notes.
  static const int maxDimension = 2400;

  /// Converts a [ui.Image] to PNG bytes.
  static Future<Uint8List> imageToPng(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List() ?? Uint8List(0);
  }

  /// Captures a [RenderRepaintBoundary] as PNG bytes at [pixelRatio].
  ///
  /// If the resulting image exceeds [maxDimension] in either dimension, it is
  /// downscaled to fit, keeping the aspect ratio.
  static Future<Uint8List> captureBoundaryToPng(
    RenderRepaintBoundary boundary, {
    double pixelRatio = 3.0,
  }) async {
    var image = await boundary.toImage(pixelRatio: pixelRatio);

    // Downscale if the captured image is very large.
    if (image.width > maxDimension || image.height > maxDimension) {
      final scaled = await _downscale(image, maxDimension);
      image.dispose();
      image = scaled;
    }

    final bytes = await imageToPng(image);
    image.dispose();
    return bytes;
  }

  /// Downscale [source] so that neither dimension exceeds [maxDim].
  static Future<ui.Image> _downscale(ui.Image source, int maxDim) async {
    final srcW = source.width;
    final srcH = source.height;
    final scale = min(maxDim / srcW, maxDim / srcH);
    final dstW = (srcW * scale).round();
    final dstH = (srcH * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()),
      Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    return picture.toImage(dstW, dstH);
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
  static Future<ExportResult> saveToGallery(
    Uint8List bytes, {
    String name = 'nook-export',
  }) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          return const ExportResult.failure(ExportFailure.permissionDenied);
        }
      }
      await Gal.putImageBytes(bytes, name: name, album: 'Nook');
      return const ExportResult.success();
    } catch (_) {
      return const ExportResult.failure(ExportFailure.unknown);
    }
  }

  /// Shares the PNG file at [filePath] via the platform share sheet.
  static Future<ExportResult> sharePng(String filePath) async {
    try {
      if (!File(filePath).existsSync()) {
        return const ExportResult.failure(ExportFailure.fileNotFound);
      }
      final params = ShareParams(files: [XFile(filePath)]);
      await SharePlus.instance.share(params);
      return const ExportResult.success();
    } catch (_) {
      return const ExportResult.failure(ExportFailure.unknown);
    }
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
