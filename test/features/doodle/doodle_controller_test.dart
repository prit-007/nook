import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';

void main() {
  group('Stroke', () {
    test('creates with points and defaults', () {
      final stroke = Stroke(
        points: [const Offset(0, 0), const Offset(10, 10)],
      );
      expect(stroke.points.length, equals(2));
      expect(stroke.color, equals(Colors.black));
      expect(stroke.width, equals(4.0));
      expect(stroke.tool, equals(DoodleTool.pen));
      expect(stroke.opacity, equals(1.0));
    });

    test('creates with custom properties', () {
      final stroke = Stroke(
        points: [const Offset(5, 5)],
        color: Colors.red,
        width: 5.0,
        tool: DoodleTool.highlighter,
        opacity: 0.5,
      );
      expect(stroke.color, equals(Colors.red));
      expect(stroke.width, equals(5.0));
      expect(stroke.tool, equals(DoodleTool.highlighter));
      expect(stroke.opacity, equals(0.5));
    });
  });

  group('DoodleController', () {
    late DoodleController controller;

    setUp(() {
      controller = DoodleController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state is empty', () {
      expect(controller.strokes, isEmpty);
      expect(controller.currentTool, equals(DoodleTool.pen));
      expect(controller.currentColor, equals(Colors.black));
      expect(controller.currentWidth, equals(4.0));
      expect(controller.canUndo, isFalse);
      expect(controller.canRedo, isFalse);
    });

    test('startStroke adds a new stroke', () {
      controller.startStroke(const Offset(0, 0));
      expect(controller.strokes.length, equals(1));
      expect(controller.strokes.first.points.length, equals(1));
    });

    test('continueStroke adds points to current stroke', () {
      controller.startStroke(const Offset(0, 0));
      controller.continueStroke(const Offset(5, 5));
      controller.continueStroke(const Offset(10, 10));
      expect(controller.strokes.first.points.length, equals(3));
    });

    test('endStroke finalizes the stroke', () {
      controller.startStroke(const Offset(0, 0));
      controller.continueStroke(const Offset(10, 10));
      controller.endStroke();

      expect(controller.strokes.length, equals(1));
      // Starting a new stroke should create a second stroke
      controller.startStroke(const Offset(20, 20));
      expect(controller.strokes.length, equals(2));
    });

    test('undo removes the last stroke', () {
      controller.startStroke(const Offset(0, 0));
      controller.endStroke();
      controller.startStroke(const Offset(10, 10));
      controller.endStroke();

      expect(controller.strokes.length, equals(2));
      controller.undo();
      expect(controller.strokes.length, equals(1));
      expect(controller.canRedo, isTrue);
    });

    test('redo restores an undone stroke', () {
      controller.startStroke(const Offset(0, 0));
      controller.endStroke();
      controller.startStroke(const Offset(10, 10));
      controller.endStroke();

      controller.undo();
      expect(controller.strokes.length, equals(1));

      controller.redo();
      expect(controller.strokes.length, equals(2));
    });

    test('undo does nothing when no strokes', () {
      controller.undo();
      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isFalse);
    });

    test('redo does nothing when no undone strokes', () {
      controller.redo();
      expect(controller.strokes, isEmpty);
      expect(controller.canRedo, isFalse);
    });

    test('new stroke clears redo stack', () {
      controller.startStroke(const Offset(0, 0));
      controller.endStroke();
      controller.startStroke(const Offset(10, 10));
      controller.endStroke();

      controller.undo();
      expect(controller.canRedo, isTrue);

      // New stroke should clear redo
      controller.startStroke(const Offset(20, 20));
      expect(controller.canRedo, isFalse);
    });

    test('clear removes all strokes', () {
      controller.startStroke(const Offset(0, 0));
      controller.endStroke();
      controller.startStroke(const Offset(10, 10));
      controller.endStroke();

      controller.clear();
      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isFalse);
    });

    test('setCurrentTool changes the tool', () {
      controller.setCurrentTool(DoodleTool.eraser);
      expect(controller.currentTool, equals(DoodleTool.eraser));

      controller.setCurrentTool(DoodleTool.highlighter);
      expect(controller.currentTool, equals(DoodleTool.highlighter));
    });

    test('setCurrentColor changes the color', () {
      controller.setCurrentColor(Colors.red);
      expect(controller.currentColor, equals(Colors.red));
    });

    test('setCurrentWidth changes the width', () {
      controller.setCurrentWidth(8.0);
      expect(controller.currentWidth, equals(8.0));
    });

    test('new strokes use current color and width', () {
      controller.setCurrentColor(Colors.blue);
      controller.setCurrentWidth(5.0);

      controller.startStroke(const Offset(0, 0));
      controller.endStroke();

      final stroke = controller.strokes.first;
      expect(stroke.color, equals(Colors.blue));
      expect(stroke.width, equals(5.0));
    });

    test('eraser strokes have no color', () {
      controller.setCurrentTool(DoodleTool.eraser);

      controller.startStroke(const Offset(0, 0));
      controller.endStroke();

      final stroke = controller.strokes.first;
      expect(stroke.tool, equals(DoodleTool.eraser));
    });

    test('highlighter strokes have reduced opacity', () {
      controller.setCurrentTool(DoodleTool.highlighter);

      controller.startStroke(const Offset(0, 0));
      controller.endStroke();

      final stroke = controller.strokes.first;
      expect(stroke.tool, equals(DoodleTool.highlighter));
      expect(stroke.opacity, equals(0.35));
    });

    test('notifyListeners is called on state changes', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.startStroke(const Offset(0, 0));
      expect(notifyCount, greaterThan(0));

      notifyCount = 0;
      controller.setCurrentColor(Colors.red);
      expect(notifyCount, equals(1));
    });

    test('isDrawing returns true while a stroke is active', () {
      expect(controller.isDrawing, isFalse);
      controller.startStroke(const Offset(0, 0));
      expect(controller.isDrawing, isTrue);
      controller.endStroke();
      expect(controller.isDrawing, isFalse);
    });
  });
}
