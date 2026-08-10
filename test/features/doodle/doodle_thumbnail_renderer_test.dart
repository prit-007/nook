import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_thumbnail_renderer.dart';

void main() {
  group('DoodleThumbnailRenderer', () {
    test('renders an empty canvas to valid PNG bytes', () async {
      final bytes = await DoodleThumbnailRenderer.render(const []);
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });

    test('renders strokes into the thumbnail', () async {
      final bytes = await DoodleThumbnailRenderer.render(
        [
          Stroke(
            points: const [
              StrokePoint(Offset(40, 40), pressure: 0.6),
              StrokePoint(Offset(80, 120), pressure: 0.4),
              StrokePoint(Offset(140, 60)),
            ],
            color: const Color(0xFFCC0000),
            width: 6,
          ),
        ],
        background: DoodleBackground.graph,
      );
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], 0x89);
    });

    test('respects the requested size', () async {
      final small = await DoodleThumbnailRenderer.render(const [],
          width: 64, height: 64);
      final large = await DoodleThumbnailRenderer.render(const [],
          width: 320, height: 240);
      expect(large.lengthInBytes, greaterThan(small.lengthInBytes));
    });
  });
}
