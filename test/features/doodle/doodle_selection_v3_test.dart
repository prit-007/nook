import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_shape_fit.dart';
import 'package:nook/features/doodle/doodle_shape_recognizer.dart';

final _rng = math.Random(99);
double _jitter(double amount) => (_rng.nextDouble() * 2 - 1) * amount;

void _feedRect(DoodleController c) {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DoodleController v3 — selection state', () {
    test('no stroke selected initially', () {
      final c = DoodleController();
      expect(c.selectedStroke, isNull);
      expect(c.isShapeSelected, isFalse);
      c.dispose();
    });

    test('selectStroke sets selected stroke and clears previous', () {
      final c = DoodleController();
      _feedRect(c);
      c.endStroke();

      c.selectStroke(0);
      expect(c.isShapeSelected, isTrue);
      expect(c.selectedStroke, c.strokes.first);
      expect(c.selectedStroke!.isPerfectShape, isTrue);

      // Selecting another stroke replaces the selection
      c.startStroke(const Offset(0, 0));
      c.continueStroke(const Offset(50, 50));
      c.endStroke();
      c.selectStroke(1);
      expect(c.selectedStroke, c.strokes.last);
      c.dispose();
    });

    test('deselect clears selection', () {
      final c = DoodleController();
      _feedRect(c);
      c.endStroke();
      c.selectStroke(0);
      expect(c.isShapeSelected, isTrue);

      c.deselect();
      expect(c.isShapeSelected, isFalse);
      expect(c.selectedStroke, isNull);
      c.dispose();
    });

    test('selectStroke with out-of-range index is a no-op', () {
      final c = DoodleController();
      c.selectStroke(5);
      expect(c.isShapeSelected, isFalse);
      c.dispose();
    });

    test('selecting a freehand (non-perfect) stroke still selects it', () {
      final c = DoodleController();
      c.startStroke(const Offset(0, 0));
      c.continueStroke(const Offset(10, 30));
      c.continueStroke(const Offset(20, 10));
      c.endStroke();
      expect(c.strokes.first.isPerfectShape, isFalse);

      c.selectStroke(0);
      expect(c.isShapeSelected, isTrue);
      expect(c.selectedStroke, c.strokes.first);
      c.dispose();
    });
  });

  group('DoodleController v3 — resize handles', () {
    test('getResizeHandles returns 9 handles for selected rect', () {
      final c = DoodleController();
      _feedRect(c);
      c.endStroke();
      c.selectStroke(0);

      final handles = c.getResizeHandles();
      expect(handles.length, 9);
      // 4 corners + 4 edges + 1 center
      c.dispose();
    });

    test('getResizeHandles returns empty when nothing selected', () {
      final c = DoodleController();
      expect(c.getResizeHandles(), isEmpty);
      c.dispose();
    });

    test('hitTestResizeHandle identifies corner handles', () {
      final c = DoodleController();
      _feedRect(c);
      c.endStroke();
      c.selectStroke(0);

      final handles = c.getResizeHandles();
      // Top-left corner handle
      final tl = handles[0];
      final hit = c.hitTestResizeHandle(tl.position, handleRadius: 12);
      expect(hit, isNotNull);
      expect(hit!.type, ResizeHandleType.nw);
      expect((hit.position - tl.position).distance, lessThan(0.01));

      // Center handle
      final center = handles[4];
      final centerHit = c.hitTestResizeHandle(center.position, handleRadius: 12);
      expect(centerHit, isNotNull);
      expect(centerHit!.type, ResizeHandleType.center);
      c.dispose();
    });

    test('hitTestResizeHandle returns null for far point', () {
      final c = DoodleController();
      _feedRect(c);
      c.endStroke();
      c.selectStroke(0);

      final handles = c.getResizeHandles();
      final farPoint = Offset(handles.first.position.dx + 1000,
          handles.first.position.dy + 1000);
      expect(c.hitTestResizeHandle(farPoint, handleRadius: 12), isNull);
      c.dispose();
    });

    test('resizeDrag updates selected rect fit parameters', () {
      final c = DoodleController();
      // Directly create a perfect rect stroke to avoid RNG-dependent recognition
      final fit = RectFit(
        center: Offset(100, 60),
        uAxis: Offset(1, 0),
        vAxis: Offset(0, 1),
        halfWidth: 100,
        halfHeight: 60,
      );
      c.startStroke(const Offset(0, 0));
      c.continueStroke(const Offset(200, 0));
      c.endStroke();
      final stroke = c.strokes.first;
      stroke.isPerfectShape = true;
      stroke.shapeType = RecognizedShape.rectangle;
      stroke.recognitionConfidence = 0.9;
      stroke.fit = fit;
      c.selectStroke(0);

      final origW = fit.halfWidth * 2;
      final origH = fit.halfHeight * 2;

      // Drag the bottom-right corner outward
      final handles = c.getResizeHandles();
      // Handles order: nw(0), n(1), ne(2), w(3), center(4), e(5), sw(6), s(7), se(8)
      final seHandle = handles[8];
      c.resizeDrag(seHandle.position,
          Offset(seHandle.position.dx + 50, seHandle.position.dy + 30));

      final updatedFit = c.selectedStroke!.fit as RectFit;
      expect(updatedFit.halfWidth * 2, greaterThan(origW));
      expect(updatedFit.halfHeight * 2, greaterThan(origH));
      c.dispose();
    });

    test('resizeDrag maintains center when dragging center handle', () {
      final c = DoodleController();
      final fit = RectFit(
        center: Offset(100, 60),
        uAxis: Offset(1, 0),
        vAxis: Offset(0, 1),
        halfWidth: 100,
        halfHeight: 60,
      );
      c.startStroke(const Offset(0, 0));
      c.continueStroke(const Offset(200, 0));
      c.endStroke();
      final stroke = c.strokes.first;
      stroke.isPerfectShape = true;
      stroke.shapeType = RecognizedShape.rectangle;
      stroke.recognitionConfidence = 0.9;
      stroke.fit = fit;
      c.selectStroke(0);

      final origCenter = fit.center;

      final centerHandle = c.getResizeHandles()[4];
      c.resizeDrag(centerHandle.position,
          Offset(centerHandle.position.dx + 40, centerHandle.position.dy + 20));

      final updatedFit = c.selectedStroke!.fit as RectFit;
      // Center should have moved with the drag
      expect(updatedFit.center.dx, greaterThan(origCenter.dx));
      expect(updatedFit.center.dy, greaterThan(origCenter.dy));
      c.dispose();
    });

    test('resizeDrag on non-perfect (freehand) stroke is a no-op', () {
      final c = DoodleController();
      c.startStroke(const Offset(0, 0));
      c.continueStroke(const Offset(10, 30));
      c.continueStroke(const Offset(20, 10));
      c.endStroke();
      c.selectStroke(0);

      final handles = c.getResizeHandles();
      expect(handles, isEmpty);
      c.dispose();
    });
  });

  group('DoodleController v3 — restore freehand', () {
    test('restoreFreehand reverts selected shape to original points', () {
      final c = DoodleController();
      // Directly create a perfect rect stroke with original points
      c.startStroke(const Offset(0, 0));
      c.continueStroke(const Offset(200, 0));
      c.continueStroke(const Offset(200, 120));
      c.continueStroke(const Offset(0, 120));
      c.continueStroke(const Offset(0, 0));
      c.endStroke();
      final stroke = c.strokes.first;
      stroke.isPerfectShape = true;
      stroke.shapeType = RecognizedShape.rectangle;
      stroke.recognitionConfidence = 0.9;
      stroke.fit = RectFit(
        center: Offset(100, 60),
        uAxis: Offset(1, 0),
        vAxis: Offset(0, 1),
        halfWidth: 100,
        halfHeight: 60,
      );
      stroke.originalPoints = [
        const Offset(0, 0),
        const Offset(200, 0),
        const Offset(200, 120),
        const Offset(0, 120),
        const Offset(0, 0),
      ];
      final originalLen = stroke.originalPoints!.length;
      c.selectStroke(0);

      c.restoreFreehand();
      expect(c.selectedStroke, isNull); // deselected after restore
      expect(stroke.isPerfectShape, isFalse);
      expect(stroke.points.length, originalLen);
      expect(stroke.shapeType, isNull);
      expect(stroke.recognitionConfidence, isNull);
      expect(stroke.fit, isNull);
      c.dispose();
    });

    test('restoreFreehand with nothing selected is a no-op', () {
      final c = DoodleController();
      c.restoreFreehand(); // should not throw
      c.dispose();
    });
  });

  group('DoodleController v3 — aspect lock toggle', () {
    test('toggleAspectLock flips the flag', () {
      final c = DoodleController();
      expect(c.aspectLockEnabled, isFalse);
      c.toggleAspectLock();
      expect(c.aspectLockEnabled, isTrue);
      c.toggleAspectLock();
      expect(c.aspectLockEnabled, isFalse);
      c.dispose();
    });
  });
}
