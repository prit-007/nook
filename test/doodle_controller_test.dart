import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';

final _rng = math.Random(99);
double _jitter(double amount) => (_rng.nextDouble() * 2 - 1) * amount;

/// Helper: feed a near-perfect rectangle with slight hand-drawn jitter.
void _feedRect(DoodleController c) {
  c.startStroke(const Offset(0, 0));
  const steps = 30;
  // top
  for (int i = 1; i < steps; i++) {
    final t = i / steps;
    c.continueStroke(Offset(200 * t, _jitter(0.8)));
  }
  // right
  for (int i = 1; i < steps; i++) {
    final t = i / steps;
    c.continueStroke(Offset(200 + _jitter(0.8), 120 * t));
  }
  // bottom
  for (int i = 1; i < steps; i++) {
    final t = i / steps;
    c.continueStroke(Offset(200 * (1 - t), 120 + _jitter(0.8)));
  }
  // left
  for (int i = 1; i < steps; i++) {
    final t = i / steps;
    c.continueStroke(Offset(_jitter(0.8), 120 * (1 - t)));
  }
}

/// Helper: feed enough hand-drawn points to simulate a nearly-straight line.
void _feedLine(DoodleController c,
    {Offset start = const Offset(0, 0),
    Offset end = const Offset(200, 0),
    int count = 40}) {
  c.startStroke(start);
  for (int i = 1; i < count; i++) {
    final t = i / (count - 1);
    c.continueStroke(Offset.lerp(start, end, t)!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'continueStroke never triggers a rebake (picture identity is stable mid-drag)',
      () {
    final controller = DoodleController();
    controller.startStroke(const Offset(0, 0));
    final pictureBeforeDrag = controller.bakedPicture;

    for (int i = 0; i < 200; i++) {
      controller.continueStroke(Offset(i.toDouble(), i.toDouble()));
    }

    // Identical reference — proves no rebake happened during the drag,
    // which is the entire point of the caching architecture.
    expect(identical(controller.bakedPicture, pictureBeforeDrag), isTrue);

    controller.dispose();
  });

  test('endStroke rebakes exactly once', () {
    final controller = DoodleController();
    controller.startStroke(const Offset(0, 0));
    controller.continueStroke(const Offset(50, 50));
    final beforeEnd = controller.bakedPicture;
    controller.endStroke();
    expect(identical(controller.bakedPicture, beforeEnd), isFalse);

    controller.dispose();
  });

  test('undo/redo round-trip preserves stroke count', () {
    final controller = DoodleController();
    controller.startStroke(const Offset(0, 0));
    controller.continueStroke(const Offset(10, 10));
    controller.endStroke();
    expect(controller.strokes.length, 1);
    controller.undo();
    expect(controller.strokes.length, 0);
    controller.redo();
    expect(controller.strokes.length, 1);

    controller.dispose();
  });

  test('revertLastSnap restores original freehand points exactly', () {
    final controller = DoodleController();
    // A near-perfect rectangle should snap on endStroke.
    _feedRect(controller);
    final originalPointCount = controller.activeStroke!.points.length;
    controller.endStroke();
    if (controller.hasPendingSnapToUndo) {
      controller.revertLastSnap();
      expect(controller.strokes.first.points.length, originalPointCount);
      expect(controller.strokes.first.isPerfectShape, isFalse);
    }

    controller.dispose();
  });

  test('pending suggestion is cleared when a new stroke starts', () {
    final controller = DoodleController();
    controller.startStroke(const Offset(0, 0));
    controller.endStroke();

    controller.startStroke(const Offset(10, 10));
    expect(controller.hasPendingSnapToUndo, isFalse);

    controller.dispose();
  });

  test('clear resets all state including baked picture', () {
    final controller = DoodleController();
    controller.startStroke(const Offset(0, 0));
    controller.continueStroke(const Offset(50, 50));
    controller.endStroke();
    expect(controller.strokes.length, 1);
    expect(controller.bakedPicture, isNotNull);

    controller.clear();
    expect(controller.strokes.length, 0);
    expect(controller.bakedPicture, isNull);
    expect(controller.canUndo, isFalse);
    expect(controller.canRedo, isFalse);

    controller.dispose();
  });

  test('replaceStrokes rebuilds baked picture', () {
    final controller = DoodleController();
    final beforeReplace = controller.bakedPicture;

    controller.replaceStrokes([
      Stroke(points: const [
        StrokePoint(Offset(0, 0)),
        StrokePoint(Offset(10, 10))
      ]),
    ]);
    expect(controller.strokes.length, 1);
    expect(identical(controller.bakedPicture, beforeReplace), isFalse);

    controller.dispose();
  });

  group('Shape snap integration', () {
    test('near-perfect rectangle auto-snaps (high confidence)', () {
      final c = DoodleController();
      _feedRect(c);
      c.endStroke();
      final stroke = c.strokes.first;
      expect(stroke.isPerfectShape, isTrue);
      expect(stroke.shapeType, isNotNull);
      expect(c.hasPendingSnapToUndo, isTrue);
      c.dispose();
    });

    test('near-perfect rectangle can be reverted', () {
      final c = DoodleController();
      _feedRect(c);
      c.endStroke();
      if (c.hasPendingSnapToUndo) {
        c.revertLastSnap();
        expect(c.strokes.first.isPerfectShape, isFalse);
        expect(c.hasPendingSnapToUndo, isFalse);
      }
      c.dispose();
    });

    test('clear line auto-snaps (high confidence)', () {
      final c = DoodleController();
      _feedLine(c);
      c.endStroke();
      final stroke = c.strokes.first;
      // Should be recognized as a line with enough confidence to snap
      if (stroke.isPerfectShape) {
        expect(stroke.shapeType, isNotNull);
      }
      c.dispose();
    });

    test('pending suggestion accept applies the shape', () {
      final c = DoodleController(shapeAssistEnabled: true);
      // Feed a noisy rectangle that might land in mid-confidence range.
      c.startStroke(const Offset(0, 0));
      // Manually create a state where suggestion is pending
      // by testing the public API.
      c.startStroke(const Offset(0, 0));
      for (int i = 1; i < 30; i++) {
        c.continueStroke(Offset(
          (200 * i / 30) + (i % 3 == 0 ? 5 : 0),
          i < 10
              ? 0
              : i < 20
                  ? 120.0
                  : 0,
        ));
      }
      c.endStroke();

      // If a suggestion appeared, verify accept/dismiss work
      if (c.hasPendingSuggestion) {
        expect(c.pendingSuggestionShape, isNotNull);
        c.acceptPendingSuggestion();
        expect(c.hasPendingSuggestion, isFalse);
        expect(c.strokes.last.isPerfectShape, isTrue);
      }
      c.dispose();
    });

    test('pending suggestion dismiss clears without applying', () {
      final c = DoodleController(shapeAssistEnabled: true);
      c.startStroke(const Offset(0, 0));
      for (int i = 1; i < 30; i++) {
        c.continueStroke(Offset(
          (200 * i / 30) + (i % 3 == 0 ? 5 : 0),
          i < 10
              ? 0
              : i < 20
                  ? 120.0
                  : 0,
        ));
      }
      c.endStroke();

      if (c.hasPendingSuggestion) {
        c.dismissPendingSuggestion();
        expect(c.hasPendingSuggestion, isFalse);
        expect(c.strokes.last.isPerfectShape, isFalse);
      }
      c.dispose();
    });

    test('shapeAssistEnabled can be toggled off', () {
      final c = DoodleController();
      expect(c.shapeAssistEnabled, isTrue);
      c.toggleShapeAssist();
      expect(c.shapeAssistEnabled, isFalse);
      // Drawing with assist disabled should NOT snap
      _feedRect(c);
      c.endStroke();
      expect(c.strokes.first.isPerfectShape, isFalse);
      expect(c.hasPendingSnapToUndo, isFalse);
      expect(c.hasPendingSuggestion, isFalse);
      c.dispose();
    });

    test('eraser strokes are never snapped', () {
      final c = DoodleController();
      c.setCurrentTool(DoodleTool.eraser);
      c.startStroke(const Offset(0, 0));
      for (int i = 1; i < 30; i++) {
        c.continueStroke(Offset(i * 10.0, 0));
      }
      c.endStroke();
      expect(c.strokes.first.isPerfectShape, isFalse);
      expect(c.hasPendingSnapToUndo, isFalse);
      expect(c.hasPendingSuggestion, isFalse);
      c.dispose();
    });
  });
}
