import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_shape_recognizer.dart';

void main() {
  group('doodle_shape_recognizer', () {
    test('returns none for too few points', () {
      final match = recognizeShape([
        const Offset(10, 10),
        const Offset(20, 20),
        const Offset(30, 30),
      ]);
      expect(match.isRecognized, isFalse);
      expect(match.shape, RecognizedShape.none);
    });

    test('returns none for tiny micro-strokes', () {
      final match = recognizeShape([
        const Offset(10, 10),
        const Offset(11, 11),
        const Offset(12, 12),
        const Offset(11, 13),
        const Offset(10, 10),
      ]);
      expect(match.isRecognized, isFalse);
    });

    test('recognizes a rough hand-drawn circle and snaps to clean circle', () {
      // Simulate drawing a hand-drawn circle with minor noise
      final raw = <Offset>[];
      const center = Offset(200, 200);
      const radius = 80.0;
      final rnd = math.Random(42);

      for (int i = 0; i <= 40; i++) {
        final angle = (i / 40) * math.pi * 2;
        final wobble = (rnd.nextDouble() - 0.5) * 6; // ±3px noise
        final r = radius + wobble;
        raw.add(center + Offset(math.cos(angle) * r, math.sin(angle) * r));
      }

      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.oval);
      expect(match.confidence, greaterThan(0.5));
      expect(match.points.length, 61);

      // Verify the snapped points form an equidistant circle from center
      final snappedCenter =
          Rect.fromPoints(match.points.first, match.points[30]).center;
      final snappedRadii = [
        for (final p in match.points) (p - snappedCenter).distance
      ];
      final firstR = snappedRadii.first;
      for (final r in snappedRadii) {
        expect((r - firstR).abs(), lessThan(0.01));
      }
    });

    test('recognizes an elongated rough oval', () {
      final raw = <Offset>[];
      const center = Offset(300, 300);
      const rx = 140.0;
      const ry = 60.0;

      for (int i = 0; i <= 45; i++) {
        final angle = (i / 45) * math.pi * 2;
        raw.add(center + Offset(math.cos(angle) * rx, math.sin(angle) * ry));
      }

      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.oval);
      expect(match.confidence, greaterThan(0.5));
    });

    test('recognizes a hand-drawn square and snaps to a perfect square', () {
      // 4 sides with slight wobble and rounded corners
      final raw = <Offset>[
        const Offset(100, 100),
        const Offset(150, 102),
        const Offset(200, 100),
        const Offset(202, 150),
        const Offset(200, 200),
        const Offset(150, 198),
        const Offset(100, 200),
        const Offset(98, 150),
        const Offset(100, 100), // closed loop
      ];

      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.confidence, greaterThan(0.5));
      expect(match.points.length, 5); // 4 corners + closed loop

      // Verify side lengths are equal (square)
      final side1 = (match.points[1] - match.points[0]).distance;
      final side2 = (match.points[2] - match.points[1]).distance;
      expect((side1 - side2).abs(), lessThan(2.0));
    });

    test('recognizes a rotated rectangle drawn at an angle', () {
      // Rotated rectangle (around 45 degrees) with points along each edge
      final raw = <Offset>[
        const Offset(200, 100),
        const Offset(235, 135),
        const Offset(270, 170),
        const Offset(235, 205),
        const Offset(200, 240),
        const Offset(165, 205),
        const Offset(130, 170),
        const Offset(165, 135),
        const Offset(200, 100),
      ];

      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.points.length, 5);
    });

    test('recognizes a hand-drawn triangle', () {
      final raw = <Offset>[
        const Offset(200, 100),
        const Offset(220, 135),
        const Offset(240, 170),
        const Offset(260, 210),
        const Offset(280, 250),
        const Offset(200, 252),
        const Offset(120, 250),
        const Offset(140, 210),
        const Offset(160, 170),
        const Offset(180, 135),
        const Offset(200, 100),
      ];

      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.triangle);
      expect(match.confidence, greaterThan(0.5));
      expect(match.points.length, 4); // 3 vertices + closed loop
    });

    test('recognizes a straight line and snaps to horizontal axis when near 0°',
        () {
      // Line drawn horizontally with small vertical wobble (angle < 4°)
      final raw = <Offset>[
        const Offset(50, 100),
        const Offset(80, 101),
        const Offset(120, 99),
        const Offset(160, 100),
        const Offset(200, 101),
        const Offset(240, 99),
        const Offset(270, 101),
        const Offset(300, 100),
      ];

      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.line);
      expect(match.confidence, greaterThan(0.7));
      expect(match.points.length, 2);

      // Verify axis snap: end.dy equals start.dy
      expect(match.points.first.dy, match.points.last.dy);
    });

    test('recognizes a vertical line and snaps to vertical axis when near 90°',
        () {
      final raw = <Offset>[
        const Offset(100, 50),
        const Offset(101, 80),
        const Offset(99, 110),
        const Offset(100, 140),
        const Offset(101, 170),
        const Offset(99, 200),
        const Offset(101, 230),
        const Offset(100, 260),
      ];

      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.line);
      expect(match.points.first.dx, match.points.last.dx);
    });

    test('recognizes an arrow stroke', () {
      // Long shaft pointing right + barb angled back
      final raw = <Offset>[
        const Offset(50, 100),
        const Offset(90, 100),
        const Offset(130, 100),
        const Offset(170, 100),
        const Offset(210, 100),
        const Offset(250, 100),
        const Offset(240, 85),
        const Offset(230, 75),
        const Offset(220, 65),
      ];

      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.arrow);
      expect(match.confidence, greaterThan(0.5));
    });

    test('recognizes a 5-point star', () {
      final raw = <Offset>[];
      const center = Offset(200, 200);
      const outerR = 80.0;
      const innerR = 32.0;
      const startAngle = -math.pi / 2;

      for (int i = 0; i < 10; i++) {
        final angle = startAngle + (i * math.pi / 5);
        final r = (i % 2 == 0) ? outerR : innerR;
        raw.add(center + Offset(math.cos(angle) * r, math.sin(angle) * r));
      }
      raw.add(raw.first);

      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.star);
      expect(match.points.length, 11);
    });

    test('returns none for random chaotic zig-zag scribbles', () {
      final raw = <Offset>[
        const Offset(50, 50),
        const Offset(200, 100),
        const Offset(60, 150),
        const Offset(220, 200),
        const Offset(40, 250),
        const Offset(180, 300),
        const Offset(50, 350),
        const Offset(210, 400),
      ];

      final match = recognizeShape(raw);
      expect(match.isRecognized, isFalse);
      expect(match.shape, RecognizedShape.none);
    });
  });
}
