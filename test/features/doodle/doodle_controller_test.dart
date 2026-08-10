import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';

void main() {
  group('Stroke', () {
    test('creates with points and defaults', () {
      final stroke = Stroke(
        points: [
          const StrokePoint(Offset(0, 0)),
          const StrokePoint(Offset(10, 10)),
        ],
      );
      expect(stroke.points.length, equals(2));
      expect(stroke.color, equals(Colors.black));
      expect(stroke.width, equals(4.0));
      expect(stroke.tool, equals(DoodleTool.pen));
      expect(stroke.opacity, equals(1.0));
    });

    test('creates with custom properties', () {
      final stroke = Stroke(
        points: [const StrokePoint(Offset(5, 5))],
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

    test('StrokePoint defaults to full pressure', () {
      const point = StrokePoint(Offset(1, 2));
      expect(point.pressure, equals(1.0));
      expect(
          const StrokePoint(Offset(1, 2), pressure: 0.3).pressure, equals(0.3));
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

    test('initial background is dotted', () {
      expect(controller.background, equals(DoodleBackground.dotted));
    });

    test('setBackground changes the background and notifies', () {
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setBackground(DoodleBackground.ruled);
      expect(controller.background, equals(DoodleBackground.ruled));
      expect(notifyCount, equals(1));

      controller.setBackground(DoodleBackground.graph);
      expect(controller.background, equals(DoodleBackground.graph));
    });

    test('background survives drawing operations', () {
      controller.setBackground(DoodleBackground.blank);
      controller.startStroke(const Offset(0, 0));
      controller.endStroke();
      controller.undo();
      controller.redo();

      expect(controller.background, equals(DoodleBackground.blank));
      expect(controller.strokes.length, equals(1));
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

    test('startStroke records stylus pressure on the first point', () {
      controller.startStroke(const Offset(5, 5), pressure: 0.2);
      final point = controller.strokes.first.points.first;
      expect(point.pressure, equals(0.2));
    });

    test('continueStroke records pressure on subsequent points', () {
      controller.startStroke(const Offset(0, 0), pressure: 1.0);
      controller.continueStroke(const Offset(10, 10), pressure: 0.4);
      controller.continueStroke(const Offset(20, 20), pressure: 0.9);

      expect(controller.strokes.first.points.length, equals(3));
      expect(controller.strokes.first.points[1].pressure, equals(0.4));
      expect(controller.strokes.first.points[2].pressure, equals(0.9));
    });

    test('points default to full pressure without an explicit value', () {
      controller.startStroke(const Offset(0, 0));
      controller.continueStroke(const Offset(5, 5));

      expect(controller.strokes.first.points.first.pressure, equals(1.0));
      expect(controller.strokes.first.points.last.pressure, equals(1.0));
    });

    test('replaceStrokes replaces the current strokes and resets redo', () {
      controller.startStroke(const Offset(0, 0));
      controller.endStroke();
      controller.startStroke(const Offset(10, 10));
      controller.endStroke();
      controller.undo();
      expect(controller.canRedo, isTrue);

      final incoming = [
        Stroke(points: [const StrokePoint(Offset(50, 50))]),
      ];
      controller.replaceStrokes(incoming);

      expect(controller.strokes.length, equals(1));
      expect(controller.strokes.single.points.single.position,
          equals(const Offset(50, 50)));
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isFalse);
      expect(controller.isDrawing, isFalse);
    });

    test('replaceStrokes clears strokes when given an empty list', () {
      controller.startStroke(const Offset(0, 0));
      controller.endStroke();

      controller.replaceStrokes(const []);
      expect(controller.strokes, isEmpty);
      expect(controller.canUndo, isFalse);
    });
  });
}
