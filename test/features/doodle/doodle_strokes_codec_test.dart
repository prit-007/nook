import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_strokes_codec.dart';

void main() {
  group('DoodleStrokesCodec', () {
    test('round trips strokes with all properties', () {
      final strokes = [
        Stroke(
          points: [
            const StrokePoint(Offset(1, 2), pressure: 0.5),
            const StrokePoint(Offset(3, 4)),
          ],
          color: const Color(0xFF3366CC),
          width: 6,
          tool: DoodleTool.highlighter,
          opacity: 0.35,
        ),
        Stroke(
          points: [const StrokePoint(Offset(0, 0), pressure: 0.9)],
          tool: DoodleTool.eraser,
        ),
      ];

      final decoded = DoodleStrokesCodec.decode(
        DoodleStrokesCodec.encode(strokes),
      );

      expect(decoded.strokes.length, equals(2));
      final first = decoded.strokes[0];
      expect(first.color, equals(const Color(0xFF3366CC)));
      expect(first.width, equals(6.0));
      expect(first.tool, equals(DoodleTool.highlighter));
      expect(first.opacity, equals(0.35));
      expect(first.points.length, equals(2));
      expect(first.points[0].position, equals(const Offset(1, 2)));
      expect(first.points[0].pressure, equals(0.5));
      expect(first.points[1].pressure, equals(1.0));
      expect(decoded.strokes[1].tool, equals(DoodleTool.eraser));
    });

    test('round trips background', () {
      final encoded = DoodleStrokesCodec.encode(
        const [],
        background: DoodleBackground.graph,
      );
      expect(DoodleStrokesCodec.decode(encoded).background,
          equals(DoodleBackground.graph));
    });

    test('defaults to dotted background and empty strokes when absent', () {
      expect(DoodleStrokesCodec.decode('{}').background,
          equals(DoodleBackground.dotted));
      expect(DoodleStrokesCodec.decode('{}').strokes, isEmpty);
    });

    test('malformed input returns empty data', () {
      expect(DoodleStrokesCodec.decode('not json').strokes, isEmpty);
      expect(DoodleStrokesCodec.decode('[]').strokes, isEmpty);
      expect(DoodleStrokesCodec.decode('{bad').strokes, isEmpty);
    });
  });
}
