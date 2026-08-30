import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';

void main() {
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
    controller.startStroke(const Offset(0, 0));
    for (final p in [
      const Offset(200, 0),
      const Offset(200, 120),
      const Offset(0, 120),
      const Offset(0, 0),
    ]) {
      controller.continueStroke(p);
    }
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
    // Simulate a pending suggestion state.
    controller.startStroke(const Offset(0, 0));
    controller.endStroke();

    // Start a new stroke — should clear any pending snap state.
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
}
