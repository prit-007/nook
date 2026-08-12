import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:nook/features/doodle/doodle_canvas.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_toolbar.dart';

void main() {
  group('DoodleToolbar', () {
    testWidgets('renders all tool buttons', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      expect(find.byIcon(LucideIcons.penLine), findsOneWidget);
      expect(find.byIcon(LucideIcons.highlighter), findsOneWidget);
      expect(find.byIcon(LucideIcons.eraser), findsOneWidget);
      expect(find.byIcon(LucideIcons.wandSparkles), findsOneWidget);
    });

    testWidgets('pen is selected by default', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      expect(controller.currentTool, equals(DoodleTool.pen));
    });

    testWidgets('tapping eraser selects eraser tool', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      await tester.tap(find.byIcon(LucideIcons.eraser));
      await tester.pumpAndSettle();

      expect(controller.currentTool, equals(DoodleTool.eraser));
    });

    testWidgets('tapping highlighter selects highlighter', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      await tester.tap(find.byIcon(LucideIcons.highlighter));
      await tester.pumpAndSettle();

      expect(controller.currentTool, equals(DoodleTool.highlighter));
    });

    testWidgets('tapping magic wand selects shape assist', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      await tester.tap(find.byIcon(LucideIcons.wandSparkles));
      await tester.pumpAndSettle();

      expect(controller.currentTool, equals(DoodleTool.shapeAssist));
    });

    testWidgets('renders color swatches', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      // Should have at least the default color swatches
      final containers = find.byType(GestureDetector);
      expect(containers, findsAtLeastNWidgets(5));
    });

    testWidgets('shows clear button', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
    });
  });

  group('DoodleCanvas', () {
    testWidgets('renders a canvas area', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleCanvas(controller: controller),
        ),
      ));

      expect(find.byType(DoodleCanvas), findsOneWidget);
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('draws a stroke on pan', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: DoodleCanvas(controller: controller),
          ),
        ),
      ));

      final center = tester.getCenter(find.byType(DoodleCanvas));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(50, 50));
      await gesture.moveBy(const Offset(50, 50));
      await gesture.up();
      await tester.pump();

      expect(controller.strokes.length, equals(1));
      expect(controller.strokes.first.points.length, greaterThanOrEqualTo(3));
    });

    testWidgets('responds to controller state changes', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: DoodleCanvas(controller: controller),
          ),
        ),
      ));

      controller.startStroke(const Offset(100, 100));
      controller.continueStroke(const Offset(150, 150));
      controller.endStroke();
      await tester.pump();

      expect(controller.strokes.length, equals(1));
    });
  });
}
