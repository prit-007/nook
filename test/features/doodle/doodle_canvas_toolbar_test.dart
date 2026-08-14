import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/features/doodle/doodle_canvas.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_toolbar.dart';

void main() {
  group('DoodleToolbar', () {
    /// The toolbar starts collapsed (only the expand handle). This helper
    /// expands it so tool assertions can inspect the full surface.
    Future<void> expandToolbar(WidgetTester tester) async {
      await tester.tap(find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedArrowUp01));
      await tester.pumpAndSettle();
    }

    testWidgets('starts collapsed with only the expand handle', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedArrowUp01),
          findsOneWidget);
      expect(
          find.byWidgetPredicate(
              (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPen01),
          findsNothing);
      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedEraser01),
          findsNothing);
    });

    testWidgets('tapping the handle expands the toolbar', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      await expandToolbar(tester);

      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedArrowDown01),
          findsOneWidget);
      expect(
          find.byWidgetPredicate(
              (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPen01),
          findsAtLeastNWidgets(1));
    });

    testWidgets('collapsed handle never overflows a phone width',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders all tool buttons', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));
      await expandToolbar(tester);

      expect(
          find.byWidgetPredicate(
              (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPen01),
          findsAtLeastNWidgets(1));
      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedHighlighter),
          findsOneWidget);
      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedEraser01),
          findsOneWidget);
      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedMagicWand01),
          findsOneWidget);
    });

    testWidgets('pen is selected by default', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));
      await expandToolbar(tester);

      expect(controller.currentTool, equals(DoodleTool.pen));
    });

    testWidgets('tapping eraser selects eraser tool', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));
      await expandToolbar(tester);

      await tester.tap(find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedEraser01));
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
      await expandToolbar(tester);

      await tester.tap(find.byWidgetPredicate((w) =>
          w is HugeIcon && w.icon == HugeIcons.strokeRoundedHighlighter));
      await tester.pumpAndSettle();

      expect(controller.currentTool, equals(DoodleTool.highlighter));
    });

    testWidgets('tapping magic wand toggles shape assist', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));
      await expandToolbar(tester);

      expect(controller.shapeAssistEnabled, isTrue);

      await tester.tap(find.byWidgetPredicate((w) =>
          w is HugeIcon && w.icon == HugeIcons.strokeRoundedMagicWand01));
      await tester.pumpAndSettle();

      expect(controller.shapeAssistEnabled, isFalse);
    });

    testWidgets('renders color swatches', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));
      await expandToolbar(tester);

      // 10 color swatches in the extended palette
      final containers = find.byType(GestureDetector);
      expect(containers, findsAtLeastNWidgets(9));
    });

    testWidgets('renders stroke width slider', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));
      await expandToolbar(tester);

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('slider changes controller width', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));
      await expandToolbar(tester);

      expect(controller.currentWidth, equals(4.0));

      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(100, 0));
      await tester.pumpAndSettle();

      expect(controller.currentWidth, isNot(equals(4.0)));
    });

    testWidgets('tapping a color swatch updates controller color',
        (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));
      await expandToolbar(tester);

      final initialColor = controller.currentColor;

      // Color swatches are inside the SingleChildScrollView, unlike tool buttons
      final colorSwatches = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(GestureDetector),
      );
      expect(colorSwatches, findsAtLeastNWidgets(2));

      // Tap the third color swatch (index 2 = Colors.redAccent)
      await tester.tap(colorSwatches.at(2));
      await tester.pumpAndSettle();

      expect(controller.currentColor, isNot(equals(initialColor)));
    });

    testWidgets('shows clear button', (tester) async {
      final controller = DoodleController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DoodleToolbar(controller: controller),
        ),
      ));
      await expandToolbar(tester);

      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete02),
          findsOneWidget);
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
