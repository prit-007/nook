import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_canvas.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_input_policy.dart';

Widget buildCanvas(DoodleController controller,
    {required ValueChanged<double> onPinchScale}) {
  return MaterialApp(
    home: Scaffold(
      body: DoodleCanvas(
        controller: controller,
        policy: DoodleInputPolicy(),
        onPinchScale: onPinchScale,
      ),
    ),
  );
}

void main() {
  group('Pinch-zoom', () {
    testWidgets('pinch-in increases scale', (tester) async {
      final controller = DoodleController();
      addTearDown(controller.dispose);

      double lastScale = 1.0;
      await tester.pumpWidget(
        buildCanvas(controller, onPinchScale: (s) => lastScale = s),
      );

      // Two fingers start 100px apart, move to 150px apart -> scale 1.5
      tester.binding.handlePointerEvent(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(50, 50),
          kind: PointerDeviceKind.touch,
        ),
      );
      tester.binding.handlePointerEvent(
        const PointerDownEvent(
          pointer: 2,
          position: Offset(150, 50),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      tester.binding.handlePointerEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(25, 50),
          kind: PointerDeviceKind.touch,
        ),
      );
      tester.binding.handlePointerEvent(
        const PointerMoveEvent(
          pointer: 2,
          position: Offset(175, 50),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      // Distance went from 100 to 150 -> ratio 1.5
      expect(lastScale, closeTo(1.5, 0.01));
    });

    testWidgets('pinch-out decreases scale', (tester) async {
      final controller = DoodleController();
      addTearDown(controller.dispose);

      double lastScale = 1.0;
      await tester.pumpWidget(
        buildCanvas(controller, onPinchScale: (s) => lastScale = s),
      );

      tester.binding.handlePointerEvent(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(50, 50),
          kind: PointerDeviceKind.touch,
        ),
      );
      tester.binding.handlePointerEvent(
        const PointerDownEvent(
          pointer: 2,
          position: Offset(150, 50),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      tester.binding.handlePointerEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(75, 50),
          kind: PointerDeviceKind.touch,
        ),
      );
      tester.binding.handlePointerEvent(
        const PointerMoveEvent(
          pointer: 2,
          position: Offset(125, 50),
          kind: PointerDeviceKind.touch,
        ),
      );
      await tester.pump();

      // Distance went from 100 to 50 -> ratio 0.5
      expect(lastScale, closeTo(0.5, 0.01));
    });
  });
}
