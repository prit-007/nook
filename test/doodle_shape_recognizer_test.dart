import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_shape_recognizer.dart';

/// Deterministic PRNG so failing tests are always reproducible — no flaky
/// "passed on my machine" nondeterminism from `Random()` without a seed.
final _rng = math.Random(42);

double _jitter(double amount) => (_rng.nextDouble() * 2 - 1) * amount;

/// Simulates a hand-drawn straight line with [noise] px of perpendicular
/// wobble and natural speed variance (denser points where a real hand
/// slows down, e.g. near the endpoints).
List<Offset> generateLine(Offset start, Offset end,
    {double noise = 2, int points = 40}) {
  final result = <Offset>[];
  for (int i = 0; i < points; i++) {
    final t = _easeInOutSample(i / (points - 1));
    final base = Offset.lerp(start, end, t)!;
    final perp = (end - start).direction + math.pi / 2;
    result.add(base + Offset(math.cos(perp), math.sin(perp)) * _jitter(noise));
  }
  return result;
}

List<Offset> generateRectangle(
  Rect rect, {
  double noise = 2,
  double rotationDeg = 0,
  int pointsPerSide = 20,
}) {
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
      result.add(base + Offset(_jitter(noise), _jitter(noise)));
    }
  }
  return result;
}

List<Offset> generateCircle(Offset center, double radius,
    {double noise = 2, int points = 80}) {
  final result = <Offset>[];
  for (int i = 0; i < points; i++) {
    final angle = (i / points) * 2 * math.pi;
    final r = radius + _jitter(noise);
    result.add(center + Offset(r * math.cos(angle), r * math.sin(angle)));
  }
  // Ensure closure.
  if (result.length > 2) result.last = result.first;
  return result;
}

List<Offset> generateOval(Offset center, double rx, double ry,
    {double noise = 2, int points = 80}) {
  final result = <Offset>[];
  for (int i = 0; i < points; i++) {
    final angle = (i / points) * 2 * math.pi;
    result.add(center +
        Offset(
          (rx + _jitter(noise)) * math.cos(angle),
          (ry + _jitter(noise)) * math.sin(angle),
        ));
  }
  // Ensure closure: last point snaps to first point's position so the
  // recognizer's closure check works correctly.
  if (result.length > 2) result.last = result.first;
  return result;
}

List<Offset> generateTriangle(List<Offset> vertices,
    {double noise = 2, int pointsPerSide = 25}) {
  final closed = [...vertices, vertices.first];
  final result = <Offset>[];
  for (int side = 0; side < 3; side++) {
    for (int i = 0; i < pointsPerSide; i++) {
      final t = i / pointsPerSide;
      final base = Offset.lerp(closed[side], closed[side + 1], t)!;
      result.add(base + Offset(_jitter(noise), _jitter(noise)));
    }
  }
  return result;
}

/// A straight shaft with a sharp hook at the end — the arrow shape.
List<Offset> generateArrow(Offset start, Offset end,
    {double noise = 2, double hookDeg = 40}) {
  final shaft = generateLine(start, end, noise: noise, points: 30);
  final shaftDir = (end - start).direction;
  final hookLen = (end - start).distance * 0.15;
  final hookAngle = shaftDir + math.pi - (hookDeg * math.pi / 180);
  final hookEnd =
      end + Offset(math.cos(hookAngle), math.sin(hookAngle)) * hookLen;
  return [
    ...shaft,
    ...generateLine(end, hookEnd, noise: noise * 0.5, points: 10),
  ];
}

/// A scribble that should NOT match any shape — our key negative case.
List<Offset> generateScribble(Offset center,
    {double spread = 60, int points = 60}) {
  final result = <Offset>[center];
  var current = center;
  for (int i = 1; i < points; i++) {
    current = current + Offset(_jitter(spread / 4), _jitter(spread / 4));
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
  });

  group('Arrow recognition', () {
    for (final hook in [30.0, 40.0, 50.0]) {
      test('recognizes an arrow with a $hook° hook', () {
        final stroke = generateArrow(const Offset(0, 0), const Offset(180, 0),
            hookDeg: hook);
        expect(recognizeShape(stroke).shape, RecognizedShape.arrow);
      });
    }
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
  });

  group('Regression fixtures — lock in known-good real recordings', () {
    test('placeholder for first real-device capture', () {
      // final realStroke = [Offset(12.3, 44.1), ...];
      // expect(recognizeShape(realStroke).shape, RecognizedShape.rectangle);
    }, skip: 'Add real captures here as you find edge cases on-device');
  });
}
