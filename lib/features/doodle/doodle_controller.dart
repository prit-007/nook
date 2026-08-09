import 'package:flutter/material.dart';

/// Drawing tools for the doodle canvas.
enum DoodleTool { pen, eraser, highlighter }

/// A single stroke composed of points with style properties.
class Stroke {
  Stroke({
    required this.points,
    this.color = Colors.black,
    this.width = 4.0,
    this.tool = DoodleTool.pen,
    this.opacity = 1.0,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final DoodleTool tool;
  final double opacity;
}

/// Controller for doodle drawing state.
/// Manages strokes, undo/redo, tool/color/width selection.
class DoodleController extends ChangeNotifier {
  final List<Stroke> _strokes = [];
  final List<Stroke> _redoStack = [];
  Stroke? _activeStroke;

  DoodleTool _currentTool = DoodleTool.pen;
  Color _currentColor = Colors.black;
  double _currentWidth = 4.0;
  bool _isDrawing = false;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  DoodleTool get currentTool => _currentTool;
  Color get currentColor => _currentColor;
  double get currentWidth => _currentWidth;
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

  void startStroke(Offset point) {
    double opacity = 1.0;
    double actualWidth = _currentWidth;

    // Adjust physical characteristics based on the active tool
    if (_currentTool == DoodleTool.highlighter) {
      opacity = 0.35;
      actualWidth = _currentWidth * 3.5; // Highlighters are inherently thicker
    } else if (_currentTool == DoodleTool.eraser) {
      actualWidth = _currentWidth * 4.0; // Erasers need wide area coverage
    }

    _activeStroke = Stroke(
      points: [point],
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

  void continueStroke(Offset point) {
    if (_activeStroke == null) return;
    _activeStroke!.points.add(point);
    notifyListeners();
  }

  void endStroke() {
    if (_activeStroke == null) return;
    _activeStroke = null;
    _isDrawing = false;
    notifyListeners();
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
}
