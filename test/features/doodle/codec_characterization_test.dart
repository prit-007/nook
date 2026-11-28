import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_strokes_codec.dart';

void main() {
  test('DoodleStrokesCodec round-trips strokes, pressure, tool, and background',
      () {
    final strokes = [
      Stroke(
        points: const [
          StrokePoint(Offset(10.5, 20.25), pressure: 0.4),
          StrokePoint(Offset(42.0, 88.5), pressure: 0.9),
        ],
        color: const Color(0xFF1E88E5),
        width: 6.5,
        tool: DoodleTool.highlighter,
        opacity: 0.5,
      ),
    ];

    final encoded = DoodleStrokesCodec.encode(
      strokes,
      background: DoodleBackground.graph,
    );
    final decoded = DoodleStrokesCodec.decode(encoded);

    expect(decoded.background, DoodleBackground.graph);
    expect(decoded.strokes, hasLength(1));
    final s = decoded.strokes.first;
    expect(s.tool, DoodleTool.highlighter);
    expect(s.width, 6.5);
    expect(s.opacity, 0.5);
    expect(s.points, hasLength(2));
    expect(s.points[0].position, const Offset(10.5, 20.25));
    expect(s.points[1].pressure, closeTo(0.9, 0.001));
  });
}
