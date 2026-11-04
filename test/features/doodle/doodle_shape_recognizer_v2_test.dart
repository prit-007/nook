import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_shape_recognizer.dart';

/// Deterministic PRNG so failing tests are always reproducible.
math.Random _seededRng(int seed) => math.Random(seed);

double _jitter(math.Random rng, double amount) =>
    (rng.nextDouble() * 2 - 1) * amount;

double _easeInOutSample(double t) => t * t * (3 - 2 * t);

Offset _rotateAround(Offset p, Offset center, double deg) {
  final rad = deg * math.pi / 180;
  final rel = p - center;
  return Offset(
    center.dx + rel.dx * math.cos(rad) - rel.dy * math.sin(rad),
    center.dy + rel.dx * math.sin(rad) + rel.dy * math.cos(rad),
  );
}

/// Hand-drawn straight line with perpendicular wobble + speed variance.
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

/// Hand-drawn rectangle with per-side jitter and optional rotation.
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

/// Hand-drawn circle with radial jitter.
List<Offset> generateCircle(Offset center, double radius,
    {double noise = 2, int points = 80, int seed = 42}) {
  final rng = _seededRng(seed);
  final result = <Offset>[];
  for (int i = 0; i < points; i++) {
    final angle = (i / points) * 2 * math.pi;
    final r = radius + _jitter(rng, noise);
    result.add(center + Offset(r * math.cos(angle), r * math.sin(angle)));
  }
  if (result.length > 2) result.last = result.first;
  return result;
}

/// Hand-drawn triangle with per-side jitter.
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

/// Chaotic scribble — must match nothing.
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

void main() {
  group('doodle_shape_recognizer v2 — normalization invariance', () {
    test('same circle at 3 scales -> same class + high confidence', () {
      final base = generateCircle(const Offset(200, 200), 60, noise: 1, seed: 7);
      final small = generateCircle(const Offset(200, 200), 30, noise: 1, seed: 7);
      final large = generateCircle(const Offset(200, 200), 120, noise: 1, seed: 7);

      final m1 = recognizeShape(base);
      final m2 = recognizeShape(small);
      final m3 = recognizeShape(large);

      expect(m1.shape, RecognizedShape.oval);
      expect(m2.shape, RecognizedShape.oval);
      expect(m3.shape, RecognizedShape.oval);
      expect(m1.confidence, greaterThan(0.7));
      expect(m2.confidence, greaterThan(0.7));
      expect(m3.confidence, greaterThan(0.7));
    });

    test('same rectangle at 4 rotations -> rectangle every time', () {
      final rect = const Rect.fromLTWH(0, 0, 200, 120);
      for (final rot in [0.0, 15.0, 45.0, 90.0, 135.0]) {
        final stroke = generateRectangle(rect, rotationDeg: rot, noise: 1.5, seed: 11);
        final match = recognizeShape(stroke);
        expect(match.shape, RecognizedShape.rectangle,
            reason: 'rotation=$rot shape=${match.shape} conf=${match.confidence}');
        expect(match.confidence, greaterThan(0.6), reason: 'rotation=$rot');
      }
    });

    test('same line at 3 speeds (point counts) -> line every time', () {
      for (final count in [20, 40, 90]) {
        final stroke = generateLine(
            const Offset(0, 0), const Offset(200, 40),
            noise: 1.5, points: count, seed: 13);
        final match = recognizeShape(stroke);
        expect(match.shape, RecognizedShape.line,
            reason: 'points=$count shape=${match.shape}');
        expect(match.confidence, greaterThan(0.7), reason: 'points=$count');
      }
    });

    test('scale invariance: tiny circle still recognized if above adaptive floor', () {
      // A deliberately drawn small circle (~30px diagonal) should be recognized.
      final stroke = generateCircle(const Offset(100, 100), 15, noise: 1, seed: 17);
      final match = recognizeShape(stroke);
      expect(match.isRecognized, isTrue,
          reason: 'small circle should be recognized, got ${match.shape}');
    });
  });

  group('doodle_shape_recognizer v2 — per-shape classification', () {
    test('recognizes a rough hand-drawn circle', () {
      final raw = generateCircle(const Offset(200, 200), 80, noise: 3, seed: 42);
      final match = recognizeShape(raw);
      expect(match.isRecognized, isTrue);
      expect(match.shape, RecognizedShape.oval);
      expect(match.confidence, greaterThan(0.5));
    });

    test('recognizes a hand-drawn square', () {
      final stroke = generateRectangle(const Rect.fromLTWH(50, 50, 150, 150),
          noise: 1.5, seed: 42);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.confidence, greaterThan(0.6));
    });

    test('recognizes a wide aspect-ratio rectangle', () {
      final stroke = generateRectangle(const Rect.fromLTWH(0, 0, 300, 80),
          noise: 1.5, seed: 42);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.confidence, greaterThan(0.6));
    });

    test('recognizes a tall aspect-ratio rectangle', () {
      final stroke = generateRectangle(const Rect.fromLTWH(0, 0, 80, 250),
          noise: 1.5, seed: 42);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle);
      expect(match.confidence, greaterThan(0.6));
    });

    test('recognizes a hand-drawn triangle', () {
      final stroke = generateTriangle([
        const Offset(100, 0),
        const Offset(200, 173),
        const Offset(0, 173),
      ], noise: 1.5, seed: 42);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.triangle);
      expect(match.confidence, greaterThan(0.6));
    });

    test('recognizes a straight line with axis snap', () {
      final raw = generateLine(const Offset(50, 100), const Offset(300, 100),
          noise: 1.5, seed: 42);
      final match = recognizeShape(raw);
      expect(match.shape, RecognizedShape.line);
      expect(match.confidence, greaterThan(0.7));
      expect(match.points.length, 2);
      expect(match.points.first.dy, match.points.last.dy);
    });

    test('recognizes an arrow stroke', () {
      final start = const Offset(50, 100);
      final end = const Offset(250, 100);
      final shaft = generateLine(start, end, noise: 1.5, points: 30, seed: 42);
      final shaftDir = (end - start).direction;
      final hookLen = (end - start).distance * 0.15;
      final hookAngle = shaftDir + math.pi - (40 * math.pi / 180);
      final hookEnd =
          end + Offset(math.cos(hookAngle), math.sin(hookAngle)) * hookLen;
      final hook = generateLine(end, hookEnd,
          noise: 1.5 * 0.5, points: 10, seed: 142);
      final raw = [...shaft, ...hook];

      final match = recognizeShape(raw);
      expect(match.shape, RecognizedShape.arrow);
      expect(match.confidence, greaterThan(0.5));
    });
  });

  group('doodle_shape_recognizer v2 — confidence bands', () {
    test('cleaner shape has higher confidence than noisy shape', () {
      final clean = recognizeShape(
          generateCircle(const Offset(100, 100), 60, noise: 0.5, seed: 42));
      final noisy = recognizeShape(
          generateCircle(const Offset(100, 100), 60, noise: 8, seed: 42));
      expect(clean.confidence, greaterThan(noisy.confidence));
      expect(clean.confidence, inInclusiveRange(0.0, 1.0));
      expect(noisy.confidence, inInclusiveRange(0.0, 1.0));
    });

    test('line confidence degrades with noise but stays line or none', () {
      for (final noise in [0.5, 2.0, 5.0]) {
        final stroke = generateLine(const Offset(0, 0), const Offset(200, 40),
            noise: noise, seed: 42);
        final match = recognizeShape(stroke);
        expect(
            match.shape,
            isNot(anyOf(
              equals(RecognizedShape.rectangle),
              equals(RecognizedShape.triangle),
              equals(RecognizedShape.oval),
            )),
            reason: 'noise=$noise falsely classified as closed shape');
        if (match.shape == RecognizedShape.line) {
          expect(match.confidence, greaterThan(0.4), reason: 'noise=$noise');
        }
      }
    });

    test('confidence range is 0.0 to 1.0 for all shapes', () {
      final shapes = [
        generateLine(const Offset(0, 0), const Offset(200, 0), noise: 1),
        generateRectangle(const Rect.fromLTWH(0, 0, 200, 120), noise: 1),
        generateCircle(const Offset(100, 100), 60, noise: 1),
        generateTriangle([
          const Offset(100, 0),
          const Offset(200, 173),
          const Offset(0, 173),
        ], noise: 1),
      ];
      for (final stroke in shapes) {
        final match = recognizeShape(stroke);
        expect(match.confidence, inInclusiveRange(0.0, 1.0),
            reason: '${match.shape} confidence=${match.confidence}');
      }
    });
  });

  group('doodle_shape_recognizer v2 — negative cases', () {
    test('a random scribble matches nothing', () {
      for (int seed = 0; seed < 10; seed++) {
        final stroke = generateScribble(Offset(seed * 30.0, 50), seed: seed);
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
      final stroke = generateRectangle(const Rect.fromLTWH(0, 0, 8, 5),
          noise: 0.5, seed: 42);
      expect(recognizeShape(stroke).shape, RecognizedShape.none);
    });

    test('an empty list matches nothing', () {
      expect(recognizeShape([]).shape, RecognizedShape.none);
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
        result.add(Offset(200 + r * math.cos(angle), 200 + r * math.sin(angle)));
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
        final angle = math.pi * (i / 40);
        result.add(Offset(100 + 80 * math.cos(angle), 100 + 80 * math.sin(angle)));
      }
      final match = recognizeShape(result);
      expect(match.shape, isNot(RecognizedShape.oval));
    });
  });

  group('doodle_shape_recognizer v2 — output geometry', () {
    test('recognized rectangle has 5 output points (closed loop)', () {
      final stroke = generateRectangle(const Rect.fromLTWH(0, 0, 200, 120),
          noise: 1, seed: 42);
      final match = recognizeShape(stroke);
      expect(match.points.length, 5);
      expect(match.points.first, match.points.last);
    });

    test('recognized triangle has 4 output points (closed)', () {
      final stroke = generateTriangle([
        const Offset(100, 0),
        const Offset(200, 173),
        const Offset(0, 173),
      ], noise: 1, seed: 42);
      final match = recognizeShape(stroke);
      expect(match.points.length, 4);
      expect(match.points.first, match.points.last);
    });

    test('line output has exactly 2 points', () {
      final stroke = generateLine(const Offset(0, 0), const Offset(200, 0),
          noise: 1, seed: 42);
      final match = recognizeShape(stroke);
      expect(match.points.length, 2);
    });

    test('square output has equal side lengths', () {
      final stroke = generateRectangle(const Rect.fromLTWH(0, 0, 150, 150),
          noise: 1, seed: 42);
      final match = recognizeShape(stroke);
      expect(match.shape, RecognizedShape.rectangle);
      final side1 = (match.points[1] - match.points[0]).distance;
      final side2 = (match.points[2] - match.points[1]).distance;
      expect((side1 - side2).abs(), lessThan(2.0),
          reason: 'square sides should be equal: $side1 vs $side2');
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
      ];
      for (final stroke in shapes) {
        final match = recognizeShape(stroke);
        if (match.isRecognized) {
          expect(match.points.length, greaterThanOrEqualTo(2),
              reason: '${match.shape} should have >=2 output points');
        }
      }
    });
  });

  group('doodle_shape_recognizer v2 — regression fixtures', () {
    test('slightly rotated noisy rectangle is recognized as rectangle', () {
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
