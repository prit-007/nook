import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';

Stroke _strokeWithPoints(List<Offset> points) {
  return Stroke(
    points: points.map((p) => StrokePoint(p, pressure: 1.0)).toList(),
    color: const Color(0xFF000000),
    width: 4.0,
    tool: DoodleTool.pen,
    opacity: 1.0,
  );
}

void main() {
  test('lasso state machine: begin/extend/end', () {
    final controller = DoodleController();

    expect(controller.lassoActive, isFalse);
    expect(controller.lassoPoints, isEmpty);

    controller.beginLasso(const Offset(0, 0));
    expect(controller.lassoActive, isTrue);
    expect(controller.lassoPoints, equals([const Offset(0, 0)]));

    controller.extendLasso(const Offset(10, 10));
    expect(controller.lassoPoints,
        equals([const Offset(0, 0), const Offset(10, 10)]));

    controller.endLasso();
    expect(controller.lassoActive, isFalse);
    expect(controller.lassoPoints, isEmpty);
  });

  test('point-in-polygon: point inside triangle', () {
    final controller = DoodleController();
    controller.lassoPoints = [
      const Offset(0, 0),
      const Offset(100, 0),
      const Offset(50, 100),
    ];

    expect(controller.pointInPolygon(const Offset(50, 30)), isTrue);
    expect(controller.pointInPolygon(const Offset(10, 10)), isTrue);
    expect(controller.pointInPolygon(const Offset(90, 10)), isTrue);
  });

  test('point-in-polygon: point outside triangle', () {
    final controller = DoodleController();
    controller.lassoPoints = [
      const Offset(0, 0),
      const Offset(100, 0),
      const Offset(50, 100),
    ];

    expect(controller.pointInPolygon(const Offset(50, 110)), isFalse);
    expect(controller.pointInPolygon(const Offset(-10, 50)), isFalse);
    expect(controller.pointInPolygon(const Offset(110, 50)), isFalse);
    expect(controller.pointInPolygon(const Offset(50, -10)), isFalse);
  });

  test('lasso selects strokes inside the loop', () {
    final controller = DoodleController();

    // Add two strokes: one inside the lasso, one outside
    controller.addStroke(_strokeWithPoints([
      const Offset(50, 50),
      const Offset(60, 50),
      const Offset(70, 50),
    ]));
    controller.addStroke(_strokeWithPoints([
      const Offset(200, 200),
      const Offset(210, 200),
      const Offset(220, 200),
    ]));

    controller.beginLasso(const Offset(0, 0));
    controller.extendLasso(const Offset(100, 0));
    controller.extendLasso(const Offset(100, 100));
    controller.extendLasso(const Offset(0, 100));
    controller.endLasso();

    expect(controller.selectedStrokeIndices, equals({0}));
    expect(controller.selectedStrokeIndices, isNot(contains(1)));
  });

  test('translateSelection moves selected strokes', () {
    final controller = DoodleController();

    controller.addStroke(_strokeWithPoints([
      const Offset(50, 50),
      const Offset(60, 50),
      const Offset(70, 50),
    ]));
    controller.addStroke(_strokeWithPoints([
      const Offset(200, 200),
      const Offset(210, 200),
      const Offset(220, 200),
    ]));

    controller.selectedStrokeIndices = {0};

    controller.translateSelection(const Offset(10, -5));

    expect(controller.strokes[0].points[0].position, const Offset(60, 45));
    expect(controller.strokes[0].points[1].position, const Offset(70, 45));
    expect(controller.strokes[0].points[2].position, const Offset(80, 45));

    // Unselected stroke unchanged
    expect(controller.strokes[1].points[0].position, const Offset(200, 200));
  });

  test('clearLassoSelection clears selection', () {
    final controller = DoodleController();
    controller.selectedStrokeIndices = {0, 1};

    controller.clearLassoSelection();

    expect(controller.selectedStrokeIndices, isEmpty);
  });
}
