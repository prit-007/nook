import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Drawing tools for the doodle canvas.
enum DoodleTool { pen, eraser, highlighter, shapeAssist }

/// Background templates for the doodle canvas.
enum DoodleBackground { blank, dotted, ruled, graph }

/// A single sampled point on a stroke, with optional stylus pressure.
class StrokePoint {
  const StrokePoint(this.position, {this.pressure = 1.0});

  final Offset position;
  final double pressure;
}

/// A single stroke composed of points with style properties.
class Stroke {
  Stroke({
    required this.points,
    this.color = Colors.black,
    this.width = 4.0,
    this.tool = DoodleTool.pen,
    this.opacity = 1.0,
    this.isPerfectShape = false,
  });

  List<StrokePoint> points;
  final Color color;
  final double width;
  final DoodleTool tool;
  final double opacity;
  bool isPerfectShape;
}

/// Controller for doodle drawing state.
/// Manages strokes, undo/redo, tool/color/width selection, and hold-to-snap
/// shape recognition.
class DoodleController extends ChangeNotifier {
  DoodleController({Color defaultColor = Colors.black})
      : _currentColor = defaultColor;

  final List<Stroke> _strokes = [];
  final List<Stroke> _redoStack = [];
  Stroke? _activeStroke;

  DoodleTool _currentTool = DoodleTool.pen;
  late Color _currentColor;
  double _currentWidth = 4.0;
  DoodleBackground _background = DoodleBackground.dotted;
  bool _isDrawing = false;

  bool _shapeAssistEnabled = true;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  DoodleTool get currentTool => _currentTool;
  Color get currentColor => _currentColor;
  double get currentWidth => _currentWidth;
  DoodleBackground get background => _background;
  bool get isDrawing => _isDrawing;
  bool get shapeAssistEnabled => _shapeAssistEnabled;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void toggleShapeAssist() {
    _shapeAssistEnabled = !_shapeAssistEnabled;
    notifyListeners();
  }

  void setCurrentTool(DoodleTool tool) {
    _currentTool = tool;
    notifyListeners();
  }

  void setCurrentColor(Color color) {
    _currentColor = color;
    notifyListeners();
  }

  void setCurrentWidth(double width) {
    _currentWidth = width;
    notifyListeners();
  }

  void setBackground(DoodleBackground background) {
    _background = background;
    notifyListeners();
  }

  void startStroke(Offset point, {double pressure = 1.0}) {
    double opacity = 1.0;
    double actualWidth = _currentWidth;

    if (_currentTool == DoodleTool.highlighter) {
      opacity = 0.35;
      actualWidth = _currentWidth * 3.5;
    } else if (_currentTool == DoodleTool.eraser) {
      actualWidth = _currentWidth * 4.0;
    }

    _activeStroke = Stroke(
      points: [StrokePoint(point, pressure: pressure)],
      color: _currentTool == DoodleTool.eraser
          ? Colors.transparent
          : _currentColor,
      width: actualWidth,
      tool: _currentTool,
      opacity: opacity,
    );
    _strokes.add(_activeStroke!);
    _redoStack.clear();
    _isDrawing = true;
    notifyListeners();
  }

  void continueStroke(Offset point, {double pressure = 1.0}) {
    if (_activeStroke == null) return;

    _activeStroke!.points.add(StrokePoint(point, pressure: pressure));
    notifyListeners();
  }

  void endStroke() {
    if (_activeStroke == null) return;
    _attemptShapeSnap();
    _activeStroke = null;
    _isDrawing = false;
    notifyListeners();
  }

  /// Discards the in-progress stroke without committing it to the canvas.
  ///
  /// Used when a second pointer lands while drawing (multi-touch scroll) so the
  /// partial single-finger stroke is removed instead of left on the paper.
  void cancelStroke() {
    if (_activeStroke == null) return;
    _strokes.remove(_activeStroke);
    _activeStroke = null;
    _isDrawing = false;
    notifyListeners();
  }

  void _attemptShapeSnap() {
    if (_activeStroke == null || _activeStroke!.points.length < 15) return;

    final points = _activeStroke!.points.map((p) => p.position).toList();
    final first = points.first;
    final last = points.last;

    final directDistance = (last - first).distance;
    double pathLength = 0.0;

    double minX = first.dx, maxX = first.dx;
    double minY = first.dy, maxY = first.dy;

    for (int i = 1; i < points.length; i++) {
      pathLength += (points[i] - points[i - 1]).distance;
      if (points[i].dx < minX) minX = points[i].dx;
      if (points[i].dx > maxX) maxX = points[i].dx;
      if (points[i].dy < minY) minY = points[i].dy;
      if (points[i].dy > maxY) maxY = points[i].dy;
    }

    final width = maxX - minX;
    final height = maxY - minY;

    // 1. Line Detection
    if (pathLength < directDistance * 1.15) {
      _activeStroke!.points = [
        StrokePoint(first, pressure: 1.0),
        StrokePoint(last, pressure: 1.0),
      ];
      _activeStroke!.isPerfectShape = true;
      notifyListeners();
      return;
    }

    // 2. Closed Shape Detection (Distance between start and end is small)
    if (directDistance < 40.0 && width > 20 && height > 20) {
      final perimeter = 2 * (width + height);
      final circumference =
          math.pi * math.max(width, height); // rough oval approx

      // Rectangle check
      if ((pathLength - perimeter).abs() < perimeter * 0.2) {
        _activeStroke!.points = [
          StrokePoint(Offset(minX, minY)),
          StrokePoint(Offset(maxX, minY)),
          StrokePoint(Offset(maxX, maxY)),
          StrokePoint(Offset(minX, maxY)),
          StrokePoint(Offset(minX, minY)), // close path
        ];
        _activeStroke!.isPerfectShape = true;
        notifyListeners();
        return;
      }

      // Oval check
      if ((pathLength - circumference).abs() < circumference * 0.25) {
        _activeStroke!.points = _generateOval(minX, minY, width, height);
        _activeStroke!.isPerfectShape = true;
        notifyListeners();
        return;
      }
    }
  }

  List<StrokePoint> _generateOval(double x, double y, double w, double h) {
    final center = Offset(x + w / 2, y + h / 2);
    final rx = w / 2;
    final ry = h / 2;
    final pts = <StrokePoint>[];
    for (int i = 0; i <= 60; i++) {
      final angle = (i / 60) * math.pi * 2;
      pts.add(StrokePoint(Offset(
          center.dx + rx * math.cos(angle), center.dy + ry * math.sin(angle))));
    }
    return pts;
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _redoStack.add(_strokes.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _strokes.add(_redoStack.removeLast());
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    _redoStack.clear();
    _activeStroke = null;
    _isDrawing = false;
    notifyListeners();
  }

  /// Replaces all strokes (used when loading a persisted doodle).
  void replaceStrokes(List<Stroke> strokes) {
    _strokes
      ..clear()
      ..addAll(strokes);
    _redoStack.clear();
    _activeStroke = null;
    _isDrawing = false;
    notifyListeners();
  }
}
