import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';

void main() {
  group('Ruler / straightedge', () {
    test('projects a point onto a ruler line', () {
      final controller = DoodleController();
      controller.toggleRuler();
      controller.rulerOrigin = const Offset(0, 0);
      controller.rulerAngle = 0; // horizontal ruler along x-axis

      // Point directly above the ruler -> projected onto the line
      final p1 = const Offset(50, 30);
      final projected1 = controller.projectPointOntoRuler(p1);
      expect(projected1, const Offset(50, 0));

      // Point already on the ruler -> unchanged
      final p2 = const Offset(100, 0);
      final projected2 = controller.projectPointOntoRuler(p2);
      expect(projected2, const Offset(100, 0));

      // Point at an angle -> projected onto the line
      final p3 = const Offset(30, 40);
      final projected3 = controller.projectPointOntoRuler(p3);
      expect(projected3, const Offset(30, 0));
    });

    test('projects onto an angled ruler', () {
      final controller = DoodleController();
      controller.toggleRuler();
      controller.rulerOrigin = const Offset(0, 0);
      controller.rulerAngle = math.pi / 4; // 45 degrees

      // Point at (100, 0) projected onto 45-degree line
      final p = const Offset(100, 0);
      final projected = controller.projectPointOntoRuler(p);

      // Projection of (100,0) onto line at 45 degrees:
      // û = (cos45, sin45) = (0.7071, 0.7071)
      // p · û = 100 * 0.7071 = 70.71
      // p' = 70.71 * (0.7071, 0.7071) = (50, 50)
      expect(projected.dx, closeTo(50, 0.01));
      expect(projected.dy, closeTo(50, 0.01));
    });

    test('ruler mode toggle', () {
      final controller = DoodleController();
      expect(controller.rulerEnabled, isFalse);

      controller.toggleRuler();
      expect(controller.rulerEnabled, isTrue);

      controller.toggleRuler();
      expect(controller.rulerEnabled, isFalse);
    });
  });
}
