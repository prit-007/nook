import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'doodle_painter.dart';
import 'doodle_shape_recognizer.dart';

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
    this.shapeType,
  });

  List<StrokePoint> points;
  final Color color;
  final double width;
  final DoodleTool tool;
  final double opacity;
  bool isPerfectShape;

  /// Set when [isPerfectShape] is true and the shape came from the
  /// recognizer — lets the painter draw shape-specific extras (e.g. an
  /// arrowhead) instead of just a generic polygon/line.
  RecognizedShape? shapeType;
}

/// Controller for doodle drawing state.
///
/// Manages strokes, undo/redo, tool/color/width selection, shape recognition
/// with a revertible "snap," and a cached baked-picture of committed strokes
/// so drawing performance doesn't degrade as a doodle grows (see [_rebake]).
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

  // Cached rendering of all committed strokes. Rebuilt only when strokes
  // are added/removed/reordered — never on every pointer move — so the
  // active stroke is the only thing recomputed at drawing frame-rate.
  Picture? _bakedPicture;

  // Revert affordance for the most recent shape snap.
  Stroke? _lastSnappedStroke;
  List<StrokePoint>? _preSnapPoints;

  // Ambiguous suggestion: stashed when confidence is in [0.45, 0.75).
  ShapeMatch? _pendingSuggestion;
  Stroke? _pendingSuggestionStroke;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  Stroke? get activeStroke => _activeStroke;
  Picture? get bakedPicture => _bakedPicture;
  DoodleTool get currentTool => _currentTool;
  Color get currentColor => _currentColor;
  double get currentWidth => _currentWidth;
  DoodleBackground get background => _background;
  bool get isDrawing => _isDrawing;
  bool get shapeAssistEnabled => _shapeAssistEnabled;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// True right after a shape snap fires — UI can show a transient
  /// "Shape recognized · tap to undo" affordance while this is true.
  bool get hasPendingSnapToUndo => _lastSnappedStroke != null;

  /// True when a mid-confidence shape match is waiting for user confirmation.
  bool get hasPendingSuggestion => _pendingSuggestion != null;

  /// The pending suggestion's recognized shape, for the UI to display.
  RecognizedShape? get pendingSuggestionShape => _pendingSuggestion?.shape;

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
    // Starting a new stroke retires any pending snap-undo affordance and
    // any pending suggestion — the user has moved on.
    _lastSnappedStroke = null;
    _preSnapPoints = null;
    _pendingSuggestion = null;
    _pendingSuggestionStroke = null;

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
    notifyListeners(); // cheap: only the active stroke recomputes, see painter
  }

  void endStroke() {
    if (_activeStroke == null) return;
    if (_shapeAssistEnabled) _attemptShapeSnap();
    _activeStroke = null;
    _isDrawing = false;
    _rebake();
    notifyListeners();
  }

  /// Discards the in-progress stroke without committing it to the canvas.
  void cancelStroke() {
    if (_activeStroke == null) return;
    _strokes.remove(_activeStroke);
    _activeStroke = null;
    _isDrawing = false;
    notifyListeners();
  }

  void _attemptShapeSnap() {
    final active = _activeStroke;
    if (active == null || active.tool == DoodleTool.eraser) return;
    if (active.points.length < 8) return;

    final raw = active.points.map((p) => p.position).toList();
    final match = recognizeShape(raw);
    if (!match.isRecognized) return;

    _preSnapPoints = active.points;

    if (match.confidence >= 0.75) {
      // High confidence: commit immediately, offer the usual undo chip.
      active.points = match.points.map((p) => StrokePoint(p)).toList();
      active.isPerfectShape = true;
      active.shapeType = match.shape;
      _lastSnappedStroke = active;
      HapticFeedback.mediumImpact();
    } else if (match.confidence >= 0.45) {
      // Ambiguous: stash as a pending suggestion, don't mutate yet.
      _pendingSuggestion = match;
      _pendingSuggestionStroke = active;
      HapticFeedback.selectionClick(); // lighter tick — "noticed", not "did"
    }
    // Below 0.45: leave the freehand stroke alone entirely, no feedback.
  }

  /// Reverts the most recent shape snap back to the original hand-drawn
  /// points. Call this from a "tap to undo" chip shown while
  /// [hasPendingSnapToUndo] is true.
  void revertLastSnap() {
    final stroke = _lastSnappedStroke;
    final original = _preSnapPoints;
    if (stroke == null || original == null) return;
    stroke.points = original;
    stroke.isPerfectShape = false;
    stroke.shapeType = null;
    _lastSnappedStroke = null;
    _preSnapPoints = null;
    _rebake();
    notifyListeners();
  }

  /// Dismisses the snap-undo affordance without reverting (e.g. after a
  /// timeout, or once the user starts a new stroke).
  void dismissSnapNotice() {
    _lastSnappedStroke = null;
    _preSnapPoints = null;
    notifyListeners();
  }

  /// Accepts a pending mid-confidence suggestion and applies it to the stroke.
  void acceptPendingSuggestion() {
    final stroke = _pendingSuggestionStroke;
    final match = _pendingSuggestion;
    if (stroke == null || match == null) return;
    stroke.points = match.points.map((p) => StrokePoint(p)).toList();
    stroke.isPerfectShape = true;
    stroke.shapeType = match.shape;
    _pendingSuggestion = null;
    _pendingSuggestionStroke = null;
    _rebake();
    notifyListeners();
  }

  /// Dismisses a pending mid-confidence suggestion without applying it.
  void dismissPendingSuggestion() {
    _pendingSuggestion = null;
    _pendingSuggestionStroke = null;
    notifyListeners();
  }

  void undo() {
    if (_strokes.isEmpty) return;
    _redoStack.add(_strokes.removeLast());
    _rebake();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _strokes.add(_redoStack.removeLast());
    _rebake();
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    _redoStack.clear();
    _activeStroke = null;
    _isDrawing = false;
    _bakedPicture?.dispose();
    _bakedPicture = null;
    notifyListeners();
  }

  /// Replaces all strokes (used when loading a persisted doodle).
  void replaceStrokes(List<Stroke> strokes) {
    _strokes
      ..clear()
      ..addAll(strokes);
    _redoStack.clear();
    _activeStroke = null;
    _rebake();
    notifyListeners();
  }

  /// Bakes every committed stroke into a single cached [Picture] so the
  /// painter never has to recompute perfect_freehand geometry for old
  /// strokes on every pointer-move frame — only the active stroke is
  /// recomputed live. Called once per completed stroke / undo / redo /
  /// load, never during an in-progress drag.
  void _rebake() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, Rect.largest);
    paintDoodleStrokes(canvas, Size.infinite, _strokes);
    _bakedPicture?.dispose();
    _bakedPicture = recorder.endRecording();
  }

  @override
  void dispose() {
    _bakedPicture?.dispose();
    super.dispose();
  }
}
