import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_strokes_codec.dart';

void main() {
  group('Doodle SVG export (Phase 5)', () {
    test('exports valid SVG with path elements and background metadata', () {
      final strokes = [
        Stroke(
          points: [
            const StrokePoint(Offset(10, 20)),
            const StrokePoint(Offset(50, 80)),
            const StrokePoint(Offset(120, 40)),
          ],
          color: const Color(0xFF6750A4),
          width: 4.5,
          tool: DoodleTool.pen,
          opacity: 0.9,
        ),
      ];

      final svg = DoodleStrokesCodec.toSvg(
        strokes,
        width: 400,
        height: 300,
        background: DoodleBackground.graph,
      );

      expect(svg, contains('<svg xmlns="http://www.w3.org/2000/svg"'));
      expect(svg, contains('viewBox="0 0 400 300"'));
      expect(svg, contains('data-nook-background="graph"'));
      expect(
          svg, contains('<path d="M10.00,20.00 L50.00,80.00 L120.00,40.00"'));
      expect(svg, contains('stroke="#6750a4"'));
      expect(svg, contains('stroke-width="4.50"'));
      expect(svg, endsWith('</svg>'));
    });
  });
}
