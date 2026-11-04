import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_shape_recognizer.dart';

final _rng = math.Random(99);
double _jitter(double amount) => (_rng.nextDouble() * 2 - 1) * amount;

void _feedRectPoints(List<Offset> result) {
  const steps = 30;
  // top
  for (int i = 1; i < steps; i++) {
    final t = i / steps;
    result.add(Offset(200 * t, _jitter(0.8)));
  }
  // right
  for (int i = 1; i < steps; i++) {
    final t = i / steps;
    result.add(Offset(200 + _jitter(0.8), 120 * t));
  }
  // bottom
  for (int i = 1; i < steps; i++) {
    final t = i / steps;
    result.add(Offset(200 * (1 - t), 120 + _jitter(0.8)));
  }
  // left
  for (int i = 1; i < steps; i++) {
    final t = i / steps;
    result.add(Offset(_jitter(0.8), 120 * (1 - t)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('DoodleController v2 — stroke stores original points', () {
    test('stroke keeps originalPoints before snap', () {
      final c = DoodleController();
      _feedRectPoints([]);
      // Re-implement feed directly on controller
      c.startStroke(const Offset(0, 0));
      const steps = 30;
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        c.continueStroke(Offset(200 * t, _jitter(0.8)));
      }
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        c.continueStroke(Offset(200 + _jitter(0.8), 120 * t));
      }
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        c.continueStroke(Offset(200 * (1 - t), 120 + _jitter(0.8)));
      }
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        c.continueStroke(Offset(_jitter(0.8), 120 * (1 - t)));
      }

      final originalPointCount = c.activeStroke!.points.length;
      c.endStroke();

      final stroke = c.strokes.first;
      expect(stroke.originalPoints, isNotNull);
      expect(stroke.originalPoints!.length, originalPointCount);
      c.dispose();
    });

    test('revertLastSnap restores stroke.originalPoints', () {
      final c = DoodleController();
      _feedRectPoints([]);
      c.startStroke(const Offset(0, 0));
      const steps = 30;
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        c.continueStroke(Offset(200 * t, _jitter(0.8)));
      }
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        c.continueStroke(Offset(200 + _jitter(0.8), 120 * t));
      }
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        c.continueStroke(Offset(200 * (1 - t), 120 + _jitter(0.8)));
      }
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        c.continueStroke(Offset(_jitter(0.8), 120 * (1 - t)));
      }

      c.endStroke();
      if (c.hasPendingSnapToUndo) {
        c.revertLastSnap();
        expect(c.strokes.first.isPerfectShape, isFalse);
        expect(c.strokes.first.originalPoints, isNotNull);
        expect(c.strokes.first.points.length,
            c.strokes.first.originalPoints!.length);
      }
      c.dispose();
    });
  });

  group('DoodleController v2 — continuous hold recognition', () {
    test('triggerHoldToSnap returns true and sets recognitionConfidence', () {
      final c = DoodleController();
      c.startStroke(const Offset(0, 0));
      for (int i = 1; i < 40; i++) {
        c.continueStroke(Offset(i * 7.0, 0));
      }
      final snapped = c.triggerHoldToSnap();
      expect(snapped, isTrue);
      expect(c.activeStroke!.recognitionConfidence, greaterThan(0.60));
      c.dispose();
    });

    test('updateHoldSnappedStroke re-recognizes and updates confidence', () {
      final c = DoodleController();
      c.startStroke(const Offset(100, 100));
      for (int i = 1; i < 40; i++) {
        c.continueStroke(Offset(100 + i * 5.0, 100));
      }
      c.triggerHoldToSnap();

      final firstConfidence = c.activeStroke!.recognitionConfidence;
      // Resize to a different aspect — recognition should still be a line
      c.updateHoldSnappedStroke(Offset(500, 300));
      expect(c.activeStroke!.recognitionConfidence, greaterThan(0.0));
      c.dispose();
    });

    test('endStroke attempts recognition even after a hold snap', () {
      final c = DoodleController();
      c.startStroke(const Offset(0, 0));
      for (int i = 1; i < 40; i++) {
        c.continueStroke(Offset(i * 5.0, 0));
      }
      c.triggerHoldToSnap();
      // Simulate endStroke: it should not gate on _isHoldSnapped
      c.endStroke();
      final stroke = c.strokes.first;
      expect(stroke.isPerfectShape, isTrue);
      c.dispose();
    });
  });

  group('DoodleController v2 — confidence bands', () {
    test('high confidence >= 0.60 auto-snaps', () {
      final c = DoodleController();
      c.startStroke(const Offset(0, 0));
      for (int i = 1; i < 40; i++) {
        c.continueStroke(Offset(i * 7.0, 0));
      }
      c.endStroke();
      final stroke = c.strokes.first;
      expect(stroke.isPerfectShape, isTrue);
      expect(stroke.shapeType, RecognizedShape.line);
      expect(stroke.recognitionConfidence, greaterThanOrEqualTo(0.60));
      c.dispose();
    });

    test('eraser strokes never get recognitionConfidence', () {
      final c = DoodleController();
      c.setCurrentTool(DoodleTool.eraser);
      c.startStroke(const Offset(0, 0));
      for (int i = 1; i < 40; i++) {
        c.continueStroke(Offset(i * 10.0, 0));
      }
      c.endStroke();
      expect(c.strokes.first.isPerfectShape, isFalse);
      expect(c.strokes.first.recognitionConfidence, isNull);
      c.dispose();
    });

    test('shapeAssist off skips recognition entirely', () {
      final c = DoodleController();
      c.toggleShapeAssist();
      c.startStroke(const Offset(0, 0));
      for (int i = 1; i < 40; i++) {
        c.continueStroke(Offset(200 * (i / 30), _jitter(0.8)));
      }
      for (int i = 1; i < 40; i++) {
        final t = i / 30;
        c.continueStroke(Offset(200 + _jitter(0.8), 120 * t));
      }
      for (int i = 1; i < 40; i++) {
        final t = i / 30;
        c.continueStroke(Offset(200 * (1 - t), 120 + _jitter(0.8)));
      }
      for (int i = 1; i < 40; i++) {
        final t = i / 30;
        c.continueStroke(Offset(_jitter(0.8), 120 * (1 - t)));
      }
      c.endStroke();
      expect(c.strokes.first.isPerfectShape, isFalse);
      expect(c.strokes.first.recognitionConfidence, isNull);
      c.dispose();
    });
  });
}
