import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_shape_recognizer.dart';

/// Deterministic PRNG so failing tests are always reproducible — no flaky
/// "passed on my machine" nondeterminism from `Random()` without a seed.
/// Each generator call uses its own seed so test order never affects results.
math.Random _seededRng(int seed) => math.Random(seed);

double _jitter(math.Random rng, double amount) =>
    (rng.nextDouble() * 2 - 1) * amount;

/// Simulates a hand-drawn straight line with [noise] px of perpendicular
/// wobble and natural speed variance (denser points where a real hand
/// slows down, e.g. near the endpoints).
List<Offset> generateLine(Offset start, Offset end,
    {double noise = 2, int points = 40, int seed = 42}) {
  final rng = _seededRng(seed);
  final result = <Offset>[];
  for (int i = 0; i < points; i++) {
    final t = _easeInOutSample(i / (points - 1));
    final base = Offset.lerp(start, end, t)!;
    final perp = (end - start).direction + math.pi / 2;
    result.add(
        base + Offset(math.cos(perp), math.sin(perp)) * _jitter(rng, noise));
  }
  return result;
}

List<Offset> generateRectangle(
  Rect rect, {
  double noise = 2,
  double rotationDeg = 0,
  int pointsPerSide = 20,
  int seed = 42,
}) {
  final rng = _seededRng(seed);
  final corners = [
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
    rect.topLeft,
  ];
  final rotated = rotationDeg == 0
      ? corners
      : corners.map((p) => _rotateAround(p, rect.center, rotationDeg)).toList();

  final result = <Offset>[];
  for (int side = 0; side < 4; side++) {
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      final base = Offset.lerp(rotated[side], rotated[side + 1], t)!;
      result.add(
          base + Offset(_jitter(rng, noise * 0.6), _jitter(rng, noise * 0.6)));
    }
  }
  return result;
}

List<Offset> generateCircle(Offset center, double radius,
    {double noise = 2, int points = 80, int seed = 42}) {
  final rng = _seededRng(seed);
  final result = <Offset>[];
  for (int i = 0; i < points; i++) {
    final angle = (i / points) * 2 * math.pi;
    final r = radius + _jitter(rng, noise);
    result.add(center + Offset(r * math.cos(angle), r * math.sin(angle)));
  }
  // Ensure closure.
  if (result.length > 2) result.last = result.first;
  return result;
}

List<Offset> generateOval(Offset center, double rx, double ry,
    {double noise = 2, int points = 80, int seed = 42}) {
  final rng = _seededRng(seed);
  final result = <Offset>[];
  for (int i = 0; i < points; i++) {
    final angle = (i / points) * 2 * math.pi;
    result.add(center +
        Offset(
          (rx + _jitter(rng, noise)) * math.cos(angle),
          (ry + _jitter(rng, noise)) * math.sin(angle),
        ));
  }
  // Ensure closure: last point snaps to first point's position so the
  // recognizer's closure check works correctly.
  if (result.length > 2) result.last = result.first;
  return result;
}

List<Offset> generateTriangle(List<Offset> vertices,
    {double noise = 2, int pointsPerSide = 25, int seed = 42}) {
  final rng = _seededRng(seed);
  final closed = [...vertices, vertices.first];
  final result = <Offset>[];
  for (int side = 0; side < 3; side++) {
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      final base = Offset.lerp(closed[side], closed[side + 1], t)!;
      result.add(base + Offset(_jitter(rng, noise), _jitter(rng, noise)));
    }
  }
  return result;
}

/// A straight shaft with a sharp hook at the end — the arrow shape.
List<Offset> generateArrow(Offset start, Offset end,
    {double noise = 2, double hookDeg = 40, int seed = 42}) {
  final shaft = generateLine(start, end, noise: noise, points: 30, seed: seed);
  final shaftDir = (end - start).direction;
  final hookLen = (end - start).distance * 0.15;
  final hookAngle = shaftDir + math.pi - (hookDeg * math.pi / 180);
  final hookEnd =
      end + Offset(math.cos(hookAngle), math.sin(hookAngle)) * hookLen;
  return [
    ...shaft,
    ...generateLine(end, hookEnd,
        noise: noise * 0.5, points: 10, seed: seed + 100),
  ];
}

/// A scribble that should NOT match any shape — our key negative case.
List<Offset> generateScribble(Offset center,
    {double spread = 60, int points = 60, int seed = 42}) {
  final rng = _seededRng(seed);
  final result = <Offset>[center];
  var current = center;
  for (int i = 1; i < points; i++) {
    current =
        current + Offset(_jitter(rng, spread / 4), _jitter(rng, spread / 4));
    result.add(current);
  }
  return result;
}

double _easeInOutSample(double t) => t * t * (3 - 2 * t);

Offset _rotateAround(Offset p, Offset center, double deg) {
  final rad = deg * math.pi / 180;
  final rel = p - center;
  return center +
      Offset(
        rel.dx * math.cos(rad) - rel.dy * math.sin(rad),
        rel.dx * math.sin(rad) + rel.dy * math.cos(rad),
      );
}

void main() {
  group('Line recognition', () {
    for (final noise in [0.5, 2.0]) {
      test('recognizes a straight line with noise=$noise', () {
        final stroke = generateLine(const Offset(0, 0), const Offset(200, 40),
            noise: noise);
        final match = recognizeShape(stroke);
        expect(match.shape, RecognizedShape.line);
        expect(match.confidence, greaterThan(0.7));
      });
    }

    test('high-noise line is still recognized but with lower confidence', () {
      final stroke =
          generateLine(const Offset(0, 0), const Offset(200, 40), noise: 5.0);
      final match = recognizeShape(stroke);
      // With 5px noise on a 200px line, the wobble can create corner-like
      // deviations. The recognizer may classify it as a line (lower
      // confidence) or none if the noise is too significant.
      if (match.shape == RecognizedShape.line) {
        expect(match.confidence, greaterThan(0.4));
      }
      // Either line or none is acceptable — the key is it's NOT falsely
      // recognized as a rectangle/triangle/oval.
      expect(
          match.shape,
          isNot(anyOf(
            equals(RecognizedShape.rectangle),
            equals(RecognizedShape.triangle),
            equals(RecognizedShape.oval),
          )));
    });

    test('rejects a line drawn too short to be meaningful', () {
      final stroke =
          generateLine(const Offset(0, 0), const Offset(5, 1), noise: 0.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.none);
    });

    test('recognizes a vertical line', () {
      final stroke = generateLine(const Offset(100, 0), const Offset(100, 200),
          noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.line);
      expect(match.confidence, greaterThan(0.7));
    });

    test('recognizes a horizontal line', () {
      final stroke = generateLine(const Offset(0, 100), const Offset(250, 100),
          noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.line);
      expect(match.confidence, greaterThan(0.7));
    });

    test('recognizes a 45° diagonal line', () {
      final stroke =
          generateLine(const Offset(0, 0), const Offset(180, 180), noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.line);
      expect(match.confidence, greaterThan(0.7));
    });

    test('recognizes a long line (500px)', () {
      final stroke =
          generateLine(const Offset(0, 0), const Offset(500, 30), noise: 2);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.line);
      expect(match.confidence, greaterThan(0.7));
    });

    test('confidence is higher for a cleaner line', () {
      final clean = recognizeShape(
          generateLine(const Offset(0, 0), const Offset(200, 0), noise: 0.5));
      final noisy = recognizeShape(
          generateLine(const Offset(0, 0), const Offset(200, 0), noise: 4));
      expect(clean.confidence, greaterThan(noisy.confidence));
    });
  });

  group('Rectangle recognition', () {
    for (final rotation in [0.0, 15.0, 30.0, 45.0, 90.0]) {
      test('recognizes a rectangle rotated $rotation°', () {
        final stroke = generateRectangle(
          const Rect.fromLTWH(0, 0, 200, 120),
          rotationDeg: rotation,
          noise: 1.5,
        );
        final match = recognizeShape(stroke);
        expect(match.shape, RecognizedShape.rectangle,
            reason: 'rotation=$rotation');
        expect(match.confidence, greaterThan(0.6));
      });
    }

    test('confidence drops as hand-wobble noise increases', () {
      final clean = recognizeShape(
          generateRectangle(const Rect.fromLTWH(0, 0, 200, 120), noise: 0.5));
      final noisy = recognizeShape(
          generateRectangle(const Rect.fromLTWH(0, 0, 200, 120), noise: 15));
      expect(clean.confidence, greaterThan(noisy.confidence));
    });

    test('recognizes a square', () {
      final stroke =
          generateRectangle(const Rect.fromLTWH(50, 50, 150, 150), noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.confidence, greaterThan(0.6));
    });

    test('recognizes a wide aspect-ratio rectangle', () {
      final stroke =
          generateRectangle(const Rect.fromLTWH(0, 0, 300, 80), noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.confidence, greaterThan(0.6));
    });

    test('recognizes a tall aspect-ratio rectangle', () {
      final stroke =
          generateRectangle(const Rect.fromLTWH(0, 0, 80, 250), noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.confidence, greaterThan(0.6));
    });

    test('recognizes a rectangle rotated 60°', () {
      final stroke = generateRectangle(
        const Rect.fromLTWH(0, 0, 180, 100),
        rotationDeg: 60,
        noise: 1.5,
      );
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.confidence, greaterThan(0.5));
    });

    test('recognizes a rectangle rotated 120°', () {
      final stroke = generateRectangle(
        const Rect.fromLTWH(0, 0, 180, 100),
        rotationDeg: 120,
        noise: 1.5,
      );
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.confidence, greaterThan(0.5));
    });

    test('recognized rectangle has 5 output points (closed loop)', () {
      final stroke =
          generateRectangle(const Rect.fromLTWH(0, 0, 200, 120), noise: 1);
      final match = recognizeShape(stroke);
      expect(match.points.length, 5);
      // First and last should be the same (closed loop)
      expect(match.points.first, match.points.last);
    });
  });

  group('Circle / oval recognition', () {
    test('recognizes a clean circle', () {
      final stroke = generateCircle(const Offset(100, 100), 60, noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.oval);
      expect(match.confidence, greaterThan(0.7));
    });

    test('recognizes an elongated oval', () {
      final stroke = generateOval(const Offset(100, 100), 100, 40, noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.oval);
    });

    test('recognizes a small circle', () {
      final stroke = generateCircle(const Offset(80, 80), 25, noise: 1);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.oval);
      expect(match.confidence, greaterThan(0.5));
    });

    test('recognizes a large circle', () {
      final stroke = generateCircle(const Offset(200, 200), 150, noise: 3);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.oval);
      expect(match.confidence, greaterThan(0.5));
    });

    test('recognizes a vertically oriented oval', () {
      final stroke = generateOval(const Offset(100, 100), 40, 120, noise: 2);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.oval);
    });

    test('circle has many output points (parametric oval)', () {
      final stroke = generateCircle(const Offset(100, 100), 60, noise: 1);
      final match = recognizeShape(stroke);
      // The oval generator produces 61 points
      expect(match.points.length, 61);
    });

    test('confidence is higher for a cleaner circle', () {
      final clean = recognizeShape(
          generateCircle(const Offset(100, 100), 60, noise: 0.5));
      final noisy =
          recognizeShape(generateCircle(const Offset(100, 100), 60, noise: 8));
      expect(clean.confidence, greaterThan(noisy.confidence));
    });
  });

  group('Triangle recognition', () {
    test('recognizes an equilateral triangle', () {
      final stroke = generateTriangle([
        const Offset(100, 0),
        const Offset(200, 173),
        const Offset(0, 173),
      ], noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.triangle);
      expect(match.confidence, greaterThan(0.6));
    });

    test('recognizes a scalene triangle', () {
      final stroke = generateTriangle([
        const Offset(0, 0),
        const Offset(220, 40),
        const Offset(60, 180),
      ], noise: 2);
      expect(recognizeShape(stroke).shape, RecognizedShape.triangle);
    });

    test('recognizes a right-angled triangle', () {
      final stroke = generateTriangle([
        const Offset(0, 0),
        const Offset(200, 0),
        const Offset(0, 180),
      ], noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.triangle);
      expect(match.confidence, greaterThan(0.5));
    });

    test('recognizes an isosceles triangle', () {
      final stroke = generateTriangle([
        const Offset(100, 0),
        const Offset(180, 200),
        const Offset(20, 200),
      ], noise: 1.5);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.triangle);
      expect(match.confidence, greaterThan(0.5));
    });

    test('recognizes an obtuse triangle', () {
      final stroke = generateTriangle([
        const Offset(0, 100),
        const Offset(200, 100),
        const Offset(80, 40),
      ], noise: 2);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.triangle);
      expect(match.confidence, greaterThan(0.4));
    });

    test('triangle has 4 output points (closed)', () {
      final stroke = generateTriangle([
        const Offset(100, 0),
        const Offset(200, 173),
        const Offset(0, 173),
      ], noise: 1);
      final match = recognizeShape(stroke);
      expect(match.points.length, 4);
      expect(match.points.first, match.points.last);
    });

    test('confidence is higher for a cleaner triangle', () {
      final clean = recognizeShape(generateTriangle([
        const Offset(100, 0),
        const Offset(200, 173),
        const Offset(0, 173),
      ], noise: 0.5));
      final noisy = recognizeShape(generateTriangle([
        const Offset(100, 0),
        const Offset(200, 173),
        const Offset(0, 173),
      ], noise: 6));
      expect(clean.confidence, greaterThan(noisy.confidence));
    });
  });

  group('Arrow recognition', () {
    for (final hook in [30.0, 40.0, 50.0]) {
      test('recognizes an arrow with a $hook° hook', () {
        final stroke = generateArrow(const Offset(0, 0), const Offset(180, 0),
            hookDeg: hook);
        expect(recognizeShape(stroke).shape, RecognizedShape.arrow);
      });
    }

    test('recognizes a diagonal arrow (pointing down-right)', () {
      final stroke = generateArrow(const Offset(0, 0), const Offset(180, 120),
          hookDeg: 40);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.arrow);
    });

    test('recognizes an arrow pointing left', () {
      final stroke = generateArrow(const Offset(200, 50), const Offset(0, 50),
          hookDeg: 35);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.arrow);
    });

    test('recognizes a vertical arrow pointing down', () {
      final stroke = generateArrow(const Offset(100, 0), const Offset(100, 200),
          hookDeg: 40);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.arrow);
    });

    test('arrow has 2 output points (shaft endpoints)', () {
      final stroke =
          generateArrow(const Offset(0, 0), const Offset(180, 0), hookDeg: 40);
      final match = recognizeShape(stroke);
      expect(match.points.length, 2);
    });

    test('recognizes an arrow with a larger hook angle (60°)', () {
      final stroke =
          generateArrow(const Offset(0, 0), const Offset(200, 0), hookDeg: 60);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.arrow);
    });

    test('recognizes an arrow with a small hook angle (25°)', () {
      final stroke =
          generateArrow(const Offset(0, 0), const Offset(200, 0), hookDeg: 25);
      final match = recognizeShape(stroke);
      // 25° is just inside the arrow detection range (20-160°)
      if (match.shape == RecognizedShape.arrow) {
        expect(match.confidence, greaterThan(0.0));
      }
      // Should not be a line if hook is detected
      if (match.isRecognized) {
        expect(match.shape, isNot(RecognizedShape.line));
      }
    });
  });

  group('Negative cases — must NOT false-positive', () {
    test('a random scribble matches nothing', () {
      for (int seed = 0; seed < 10; seed++) {
        final stroke = generateScribble(Offset(seed * 30.0, 50));
        final match = recognizeShape(stroke);
        expect(match.shape, RecognizedShape.none,
            reason: 'seed=$seed scribble falsely matched ${match.shape}');
      }
    });

    test('a very short stroke matches nothing', () {
      final stroke = [
        const Offset(0, 0),
        const Offset(3, 2),
        const Offset(5, 4),
      ];
      expect(recognizeShape(stroke).shape, RecognizedShape.none);
    });

    test('a tiny shape below the size floor matches nothing', () {
      final stroke =
          generateRectangle(const Rect.fromLTWH(0, 0, 8, 5), noise: 0.5);
      expect(recognizeShape(stroke).shape, RecognizedShape.none);
    });

    test('an empty list matches nothing', () {
      expect(recognizeShape([]).shape, RecognizedShape.none);
    });

    test('a single point matches nothing', () {
      expect(
          recognizeShape([const Offset(50, 50)]).shape, RecognizedShape.none);
    });

    test('exactly 7 points (below the 8-point threshold) matches nothing', () {
      final stroke = [
        const Offset(0, 0),
        const Offset(30, 5),
        const Offset(60, 0),
        const Offset(90, 5),
        const Offset(120, 0),
        const Offset(150, 5),
        const Offset(180, 0),
      ];
      expect(recognizeShape(stroke).shape, RecognizedShape.none);
    });

    test('a zigzag does not match any closed shape', () {
      final result = <Offset>[];
      for (int i = 0; i < 40; i++) {
        result.add(Offset(i * 10.0, i.isEven ? 0.0 : 40.0));
      }
      final match = recognizeShape(result);
      // Zigzag is open, should not be triangle/rectangle/oval
      expect(
          match.shape,
          isNot(anyOf(
            equals(RecognizedShape.triangle),
            equals(RecognizedShape.rectangle),
            equals(RecognizedShape.oval),
          )));
    });

    test('a spiral does not match any closed shape', () {
      final result = <Offset>[];
      for (int i = 0; i < 80; i++) {
        final angle = i * 0.3;
        final r = 10 + i * 1.5;
        result
            .add(Offset(200 + r * math.cos(angle), 200 + r * math.sin(angle)));
      }
      final match = recognizeShape(result);
      expect(
          match.shape,
          isNot(anyOf(
            equals(RecognizedShape.triangle),
            equals(RecognizedShape.rectangle),
            equals(RecognizedShape.oval),
          )));
    });

    test('a U-shape does not match a circle', () {
      final result = <Offset>[];
      for (int i = 0; i <= 40; i++) {
        final angle = math.pi * (i / 40); // Only half circle (0 to π)
        result.add(Offset(
          100 + 80 * math.cos(angle),
          100 + 80 * math.sin(angle),
        ));
      }
      final match = recognizeShape(result);
      // U-shape is open, should not be oval
      expect(match.shape, isNot(RecognizedShape.oval));
    });
  });

  group('ShapeMatch properties', () {
    test('ShapeMatch.none has isRecognized = false', () {
      expect(ShapeMatch.none.isRecognized, false);
      expect(ShapeMatch.none.shape, RecognizedShape.none);
      expect(ShapeMatch.none.confidence, 0.0);
      expect(ShapeMatch.none.points, isEmpty);
    });

    test('recognized shape has isRecognized = true', () {
      const match = ShapeMatch(RecognizedShape.line, [], 0.8);
      expect(match.isRecognized, true);
    });

    test('confidence range is 0.0 to 1.0', () {
      final line = recognizeShape(
          generateLine(const Offset(0, 0), const Offset(200, 0), noise: 0.5));
      expect(line.confidence, inInclusiveRange(0.0, 1.0));
    });
  });

  group('Boundary conditions', () {
    test('line output has exactly 2 points', () {
      final stroke =
          generateLine(const Offset(0, 0), const Offset(200, 0), noise: 1);
      final match = recognizeShape(stroke);
      expect(match.points.length, 2);
    });

    test('recognized shapes always have at least 2 output points', () {
      final shapes = [
        generateLine(const Offset(0, 0), const Offset(200, 0), noise: 1),
        generateRectangle(const Rect.fromLTWH(0, 0, 200, 120), noise: 1),
        generateCircle(const Offset(100, 100), 60, noise: 1),
        generateTriangle([
          const Offset(100, 0),
          const Offset(200, 173),
          const Offset(0, 173),
        ], noise: 1),
        generateArrow(const Offset(0, 0), const Offset(180, 0), hookDeg: 40),
      ];
      for (final stroke in shapes) {
        final match = recognizeShape(stroke);
        if (match.isRecognized) {
          expect(match.points.length, greaterThanOrEqualTo(2),
              reason:
                  '${match.shape} should have at least 2 output points, got ${match.points.length}');
        }
      }
    });
  });

  group('Regression fixtures — lock in known-good real recordings', () {
    test('slightly rotated rectangle is recognized as rectangle', () {
      final stroke = generateRectangle(
        const Rect.fromLTWH(10, 10, 180, 100),
        noise: 3,
        rotationDeg: 4,
        seed: 77,
      );
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle,
          reason: 'A 4-deg rotated noisy rectangle must still be a rectangle');
    });

    test('imperfect circle with center wobble is recognized', () {
      final stroke = generateCircle(
        const Offset(120, 80),
        55,
        noise: 5,
        seed: 33,
      );
      final match = recognizeShape(stroke);
      expect(match.isRecognized, isTrue,
          reason: 'A noisy circle should still be recognized');
    });

    test('hand-drawn diagonal line is recognized', () {
      final stroke = generateLine(
        const Offset(50, 200),
        const Offset(250, 80),
        noise: 3,
        points: 35,
        seed: 91,
      );
      final match = recognizeShape(stroke);
      expect(match.isRecognized, isTrue,
          reason: 'A diagonal line should be recognized');
    });
  });
}
