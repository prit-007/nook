import 'dart:typed_data';

import 'package:zxing2/qrcode.dart';

/// Pixel layouts produced by the `camera` plugin's image stream.
enum QrPixelFormat { yuv420, bgra8888 }

/// A single color plane of a camera frame.
class QrCameraPlane {
  const QrCameraPlane({required this.bytes, required this.bytesPerRow});

  final Uint8List bytes;

  /// Row stride of [bytes], in bytes. May exceed the logical row width when
  /// the platform pads each row (Android YUV planes do).
  final int bytesPerRow;
}

/// Plugin-independent representation of one camera frame, decoupled from the
/// `camera` package so the decode pipeline is unit-testable without a device.
class QrCameraFrame {
  const QrCameraFrame({
    required this.format,
    required this.width,
    required this.height,
    required this.planes,
  });

  final QrPixelFormat format;
  final int width;
  final int height;
  final List<QrCameraPlane> planes;
}

/// Attempts to decode a QR code from [frame]. Returns the decoded text, or
/// null when the frame does not contain a readable QR code.
String? decodeQrFromFrame(QrCameraFrame frame) {
  final source = switch (frame.format) {
    QrPixelFormat.yuv420 => _yuv420LuminanceSource(frame),
    QrPixelFormat.bgra8888 => _bgra8888LuminanceSource(frame),
  };
  if (source == null) return null;

  try {
    final result = QRCodeReader().decode(BinaryBitmap(HybridBinarizer(source)));
    return result.text;
  } on ReaderException {
    return null;
  }
}

/// Extracts a luminance source from an Android YUV_420_888 frame.
///
/// The Y (luma) plane is [frame.planes][0]; each row may be padded to
/// `bytesPerRow`, so rows are compacted to exactly [frame.width] bytes and
/// packed into an ARGB pixel list where every channel holds the luma value.
LuminanceSource? _yuv420LuminanceSource(QrCameraFrame frame) {
  if (frame.planes.isEmpty || frame.width <= 0 || frame.height <= 0) {
    return null;
  }
  final y = frame.planes[0];
  final dataWidth = y.bytesPerRow;
  if (dataWidth < frame.width || y.bytes.length < dataWidth * frame.height) {
    return null;
  }
  final argb = Int32List(frame.width * frame.height);
  for (var row = 0; row < frame.height; row++) {
    final src = row * dataWidth;
    final dst = row * frame.width;
    for (var col = 0; col < frame.width; col++) {
      final luma = y.bytes[src + col];
      argb[dst + col] = (0xFF << 24) | (luma << 16) | (luma << 8) | luma;
    }
  }
  return RGBLuminanceSource(frame.width, frame.height, argb);
}

/// Extracts a luminance source from an iOS BGRA8888 frame (single plane,
/// 4 bytes per pixel, row stride = width * 4).
LuminanceSource? _bgra8888LuminanceSource(QrCameraFrame frame) {
  final plane = frame.planes.firstOrNull;
  if (plane == null || frame.width <= 0 || frame.height <= 0) {
    return null;
  }
  final pixels = plane.bytes;
  final stride = plane.bytesPerRow;
  final minRowBytes = frame.width * 4;
  if (stride < minRowBytes || pixels.length < stride * frame.height) {
    return null;
  }
  final argb = Int32List(frame.width * frame.height);
  for (var row = 0; row < frame.height; row++) {
    final rowStart = row * stride;
    final outStart = row * frame.width;
    for (var col = 0; col < frame.width; col++) {
      final i = rowStart + col * 4;
      final b = pixels[i];
      final g = pixels[i + 1];
      final r = pixels[i + 2];
      final a = pixels[i + 3];
      argb[outStart + col] = (a << 24) | (r << 16) | (g << 8) | b;
    }
  }
  return RGBLuminanceSource(frame.width, frame.height, argb);
}
