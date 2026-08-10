import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_canvas.dart';
import 'package:nook/features/doodle/doodle_controller.dart';

void main() {
  Widget buildCanvas(DoodleController controller) {
    return MaterialApp(
      home: Scaffold(
        body: DoodleCanvas(controller: controller),
      ),
    );
  }

  testWidgets('records stylus pressure from pointer events', (tester) async {
    final controller = DoodleController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(buildCanvas(controller));

    const pointer = 7;
    tester.binding.handlePointerEvent(
      const PointerDownEvent(
        pointer: pointer,
        position: Offset(50, 50),
        pressure: 0.25,
      ),
    );
    await tester.pump();
    tester.binding.handlePointerEvent(
      const PointerMoveEvent(
        pointer: pointer,
        position: Offset(60, 60),
        pressure: 0.8,
      ),
    );
    await tester.pump();
    tester.binding.handlePointerEvent(
      const PointerUpEvent(pointer: pointer, position: Offset(60, 60)),
    );
    await tester.pump();

    expect(controller.strokes.length, equals(1));
    expect(controller.strokes.first.points.length, equals(2));
    expect(controller.strokes.first.points.first.pressure, equals(0.25));
    expect(controller.strokes.first.points.last.pressure, equals(0.8));
  });

  testWidgets('releases a stroke on pointer cancel', (tester) async {
    final controller = DoodleController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(buildCanvas(controller));

    const pointer = 3;
    tester.binding.handlePointerEvent(
      const PointerDownEvent(pointer: pointer, position: Offset(10, 10)),
    );
    await tester.pump();
    tester.binding.handlePointerEvent(
      const PointerCancelEvent(pointer: pointer),
    );
    await tester.pump();

    expect(controller.strokes.length, equals(1));
    expect(controller.isDrawing, isFalse);
  });
}
