import 'dart:async';
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

  // --- Hold-to-snap engine ---
  Timer? _holdTimer;
  Offset? _lastPosition;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  DoodleTool get currentTool => _currentTool;
  Color get currentColor => _currentColor;
  double get currentWidth => _currentWidth;
  DoodleBackground get background => _background;
  bool get isDrawing => _isDrawing;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

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
    _lastPosition = point;

    if (_currentTool == DoodleTool.pen ||
        _currentTool == DoodleTool.shapeAssist) {
      _startHoldTimer();
    }
    notifyListeners();
  }

  void continueStroke(Offset point, {double pressure = 1.0}) {
    if (_activeStroke == null) return;

    if (_lastPosition != null && (point - _lastPosition!).distance > 2.0) {
      _activeStroke!.points.add(StrokePoint(point, pressure: pressure));
      _lastPosition = point;
      _startHoldTimer();
      notifyListeners();
    }
  }

  void endStroke() {
    _holdTimer?.cancel();
    if (_activeStroke == null) return;
    _activeStroke = null;
    _isDrawing = false;
    notifyListeners();
  }

  void _startHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 400), () {
      _attemptShapeSnap();
    });
  }

  void _attemptShapeSnap() {
    if (_activeStroke == null || _activeStroke!.points.length < 10) return;

    final points = _activeStroke!.points.map((p) => p.position).toList();
    final first = points.first;
    final last = points.last;

    // 1. Line Detection
    final distance = (last - first).distance;
    double pathLength = 0.0;
    for (int i = 1; i < points.length; i++) {
      pathLength += (points[i] - points[i - 1]).distance;
    }

    if (pathLength < distance * 1.15) {
      _activeStroke!.points = [
        StrokePoint(first, pressure: 1.0),
        StrokePoint(last, pressure: 1.0),
      ];
      _activeStroke!.isPerfectShape = true;
      notifyListeners();
      return;
    }

    // 2. Closed Shape Detection (Circle/Ellipse)
    if ((last - first).distance < 30.0) {
      double minX = points.first.dx, maxX = points.first.dx;
      double minY = points.first.dy, maxY = points.first.dy;
      for (final p in points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }

      final width = maxX - minX;
      final height = maxY - minY;

      if (width > 0 && height > 0) {
        _activeStroke!.points = _generatePerfectOval(minX, minY, width, height);
        _activeStroke!.isPerfectShape = true;
        notifyListeners();
      }
    }
  }

  List<StrokePoint> _generatePerfectOval(
      double x, double y, double w, double h) {
    final center = Offset(x + w / 2, y + h / 2);
    final radiusX = w / 2;
    final radiusY = h / 2;
    final points = <StrokePoint>[];

    for (int i = 0; i <= 60; i++) {
      final angle = (i / 60) * math.pi * 2;
      points.add(StrokePoint(
        Offset(center.dx + radiusX * math.cos(angle),
            center.dy + radiusY * math.sin(angle)),
        pressure: 1.0,
      ));
    }
    return points;
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
