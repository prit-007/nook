import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_shape_fit.dart';
import 'package:nook/features/doodle/doodle_shape_recognizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShapeFit — resizable geometry generation', () {
    test('LineFit generates exactly 2 points at drawn size', () {
      final fit = const LineFit(start: Offset(10, 10), end: Offset(100, 10));
      final points = fit.generatePoints(const Size(200, 200));
      expect(points.length, 2);
      expect(points.first, Offset(10, 10));
      expect(points.last, Offset(100, 10));
    });

    test('LineFit clamps to minRenderSize when drawn too small', () {
      final fit = const LineFit(start: Offset(10, 10), end: Offset(30, 10));
      final points = fit.generatePoints(const Size(200, 200), minRenderSize: 40);
      expect(points.length, 2);
      final diag = (points.last - points.first).distance;
      expect(diag, greaterThanOrEqualTo(40 - 0.01));
      // Center preserved
      final center = (points.first + points.last) / 2;
      expect(center.dx, 20);
      expect(center.dy, 10);
    });

    test('RectFit generates closed loop (5 points)', () {
      final fit = RectFit(
        center: Offset(100, 100),
        uAxis: Offset(1, 0),
        vAxis: Offset(0, 1),
        halfWidth: 50,
        halfHeight: 30,
      );
      final points = fit.generatePoints(const Size(200, 200));
      expect(points.length, 5);
      expect(points.first, points.last);
    });

    test('RectFit clamps to minRenderSize', () {
      final fit = RectFit(
        center: Offset(100, 100),
        uAxis: Offset(1, 0),
        vAxis: Offset(0, 1),
        halfWidth: 10,
        halfHeight: 5,
      );
      final points = fit.generatePoints(const Size(200, 200), minRenderSize: 40);
      final xs = points.map((p) => p.dx).toList();
      final ys = points.map((p) => p.dy).toList();
      final w = xs.reduce(math.max) - xs.reduce(math.min);
      final h = ys.reduce(math.max) - ys.reduce(math.min);
      final diag = math.sqrt(w * w + h * h);
      expect(diag, greaterThanOrEqualTo(40 - 0.01));
    });

    test('OvalFit generates 61 points', () {
      final fit = const OvalFit(center: Offset(100, 100), rx: 60, ry: 40);
      final points = fit.generatePoints(const Size(200, 200));
      expect(points.length, 61);
    });

    test('OvalFit clamps radius to minRenderSize/2', () {
      final fit = const OvalFit(center: Offset(100, 100), rx: 5, ry: 5);
      final points = fit.generatePoints(const Size(200, 200), minRenderSize: 40);
      final maxDist = points.map((p) => (p - Offset(100, 100)).distance).reduce(math.max);
      expect(maxDist, greaterThanOrEqualTo(19.9));
    });

    test('NoneFit returns empty', () {
      final fit = const NoneFit();
      expect(fit.generatePoints(const Size(200, 200)), isEmpty);
    });

    test('TriangleFit generates closed loop (4 points)', () {
      final fit = TriangleFit(
        a: Offset(100, 10),
        b: Offset(150, 100),
        c: Offset(50, 100),
      );
      final points = fit.generatePoints(const Size(200, 200));
      expect(points.length, 4);
      expect(points.first, points.last);
    });

    test('StarFit generates 11 points', () {
      final fit = const StarFit(center: Offset(100, 100), outerRadius: 40);
      final points = fit.generatePoints(const Size(200, 200));
      expect(points.length, 11);
      expect(points.first, points.last);
    });
  });

  group('minRenderSize clamp — shape never too small to verify', () {
    List<Offset> _applyMinRenderSize(List<Offset> points, double minRenderSize) {
      if (points.isEmpty) return points;
      double minX = points.first.dx, maxX = points.first.dx;
      double minY = points.first.dy, maxY = points.first.dy;
      for (final p in points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      final bounds = Rect.fromLTRB(minX, minY, maxX, maxY);
      final w = bounds.width;
      final h = bounds.height;
      final scaleX = w > 0 && w < minRenderSize ? minRenderSize / w : 1.0;
      final scaleY = h > 0 && h < minRenderSize ? minRenderSize / h : 1.0;
      final scale = math.max(scaleX, scaleY);
      if (scale == 1.0) return points;
      final center = bounds.center;
      return points.map((p) => center + (p - center) * scale).toList();
    }

    test('tiny line is scaled up to minRenderSize', () {
      final points = [Offset(10, 10), Offset(20, 10)];
      final scaled = _applyMinRenderSize(points, 40);
      final diag = (scaled.last - scaled.first).distance;
      expect(diag, greaterThanOrEqualTo(39.9));
    });

    test('normal-size line is unchanged', () {
      final points = [Offset(10, 10), Offset(100, 10)];
      final scaled = _applyMinRenderSize(points, 40);
      expect(scaled, equals(points));
    });

    test('tiny oval is scaled up from center', () {
      final points = [
        for (int i = 0; i <= 60; i++)
          Offset(100 + 5 * math.cos((i / 60) * math.pi * 2), 100 + 5 * math.sin((i / 60) * math.pi * 2)),
      ];
      final scaled = _applyMinRenderSize(points, 40);
      final center = Offset(100, 100);
      final maxDist = scaled.map((p) => (p - center).distance).reduce(math.max);
      expect(maxDist, greaterThanOrEqualTo(19.9));
    });
  });

  group('Stroke.fit integration', () {
    test('Stroke holds fit, recognitionConfidence, and originalPoints', () {
      final fit = const LineFit(start: Offset(0, 0), end: Offset(100, 0));
      final stroke = Stroke(
        points: const [StrokePoint(Offset(0, 0)), StrokePoint(Offset(100, 0))],
        originalPoints: const [Offset(0, 0), Offset(5, 1), Offset(100, 0)],
        isPerfectShape: true,
        shapeType: RecognizedShape.line,
        recognitionConfidence: 0.85,
        fit: fit,
      );
      expect(stroke.recognitionConfidence, 0.85);
      expect(stroke.shapeType, RecognizedShape.line);
      expect(stroke.fit, isA<LineFit>());
      expect((stroke.fit as LineFit).start, Offset(0, 0));
      expect((stroke.fit as LineFit).end, Offset(100, 0));
      expect(stroke.originalPoints, hasLength(3));
    });
  });
}
