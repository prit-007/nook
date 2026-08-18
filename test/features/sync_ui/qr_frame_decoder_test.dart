import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/sync_ui/widgets/qr_frame_decoder.dart';
import 'package:zxing2/qrcode.dart';

QrCameraFrame _yuv420Frame(
  int width,
  int height,
  List<int> yPlane, {
  int? rowStride,
}) {
  final stride = rowStride ?? width;
  final padded = Uint8List(stride * height);
  for (var row = 0; row < height; row++) {
    padded.setRange(row * stride, row * stride + width,
        yPlane.sublist(row * width, (row + 1) * width));
  }
  return QrCameraFrame(
    format: QrPixelFormat.yuv420,
    width: width,
    height: height,
    planes: [
      QrCameraPlane(bytes: padded, bytesPerRow: stride),
      QrCameraPlane(
          bytes: Uint8List((stride ~/ 2) * (height ~/ 2)),
          bytesPerRow: stride ~/ 2),
      QrCameraPlane(
          bytes: Uint8List((stride ~/ 2) * (height ~/ 2)),
          bytesPerRow: stride ~/ 2),
    ],
  );
}

/// Renders [text] as a QR code and returns a [QrCameraFrame] in the requested
/// pixel format.
QrCameraFrame _qrFrame(String text, QrPixelFormat format, {int scale = 4}) {
  final matrix = Encoder.encode(text, ErrorCorrectionLevel.h).matrix!;
  final mw = matrix.width;
  final mh = matrix.height;
  final width = mw * scale;
  final height = mh * scale;

  final y = List<int>.filled(width * height, 255);
  final bgra = Uint8List(width * height * 4);
  for (var i = 0; i < bgra.length; i += 4) {
    bgra[i] = 255; // B
    bgra[i + 1] = 255; // G
    bgra[i + 2] = 255; // R
    bgra[i + 3] = 255; // A
  }
  for (var my = 0; my < mh; my++) {
    for (var mx = 0; mx < mw; mx++) {
      final black = matrix.get(mx, my) == 1;
      for (var sy = 0; sy < scale; sy++) {
        for (var sx = 0; sx < scale; sx++) {
          final x = mx * scale + sx;
          final yy = my * scale + sy;
          final idx = yy * width + x;
          if (black) {
            y[idx] = 0;
            final boff = idx * 4;
            bgra[boff] = 0; // B
            bgra[boff + 1] = 0; // G
            bgra[boff + 2] = 0; // R
            bgra[boff + 3] = 255; // A
          }
        }
      }
    }
  }

  switch (format) {
    case QrPixelFormat.yuv420:
      return _yuv420Frame(width, height, y);
    case QrPixelFormat.bgra8888:
      return QrCameraFrame(
        format: QrPixelFormat.bgra8888,
        width: width,
        height: height,
        planes: [QrCameraPlane(bytes: bgra, bytesPerRow: width * 4)],
      );
  }
}

void main() {
  group('decodeQrFromFrame', () {
    const multiaddr =
        '/ip4/192.168.1.20/udp/52341/udx/p2p/12D3KooW1234567890abcdef';

    test('decodes a QR from a yuv420 frame', () {
      final frame = _qrFrame(multiaddr, QrPixelFormat.yuv420);
      expect(decodeQrFromFrame(frame), multiaddr);
    });

    test('decodes a QR from a bgra8888 frame (iOS)', () {
      final frame = _qrFrame(multiaddr, QrPixelFormat.bgra8888);
      expect(decodeQrFromFrame(frame), multiaddr);
    });

    test('handles yuv420 frames with row stride padding', () {
      final matrix = Encoder.encode(multiaddr, ErrorCorrectionLevel.h).matrix!;
      final scale = 4;
      final width = matrix.width * scale;
      final height = matrix.height * scale;
      final y = List<int>.filled(width * height, 255);
      for (var my = 0; my < matrix.height; my++) {
        for (var mx = 0; mx < matrix.width; mx++) {
          if (matrix.get(mx, my) == 1) {
            for (var sy = 0; sy < scale; sy++) {
              for (var sx = 0; sx < scale; sx++) {
                y[(my * scale + sy) * width + (mx * scale + sx)] = 0;
              }
            }
          }
        }
      }
      final frame = _yuv420Frame(width, height, y, rowStride: width + 8);
      expect(decodeQrFromFrame(frame), multiaddr);
    });

    test('returns null when no QR is present (blank white frame)', () {
      final frame = _yuv420Frame(200, 200, List.filled(200 * 200, 255));
      expect(decodeQrFromFrame(frame), isNull);
    });

    test('returns null for malformed frames (truncated bgra bytes)', () {
      final frame = _qrFrame(multiaddr, QrPixelFormat.bgra8888);
      final truncated = QrCameraFrame(
        format: QrPixelFormat.bgra8888,
        width: frame.width,
        height: frame.height,
        planes: [
          QrCameraPlane(
            bytes: frame.planes.single.bytes.sublist(0, 64),
            bytesPerRow: frame.planes.single.bytesPerRow,
          ),
        ],
      );
      expect(decodeQrFromFrame(truncated), isNull);
    });
  });
}
