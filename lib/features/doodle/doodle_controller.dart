import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'doodle_painter.dart';
import 'doodle_shape_fit.dart';
import 'doodle_shape_recognizer.dart';

/// Minimum rendered size (logical pixels) for any perfect shape, so a shape
/// is never too small for the user to verify it was recognized correctly.
const double _minRenderSize = 40.0;

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
    this.originalPoints,
    this.recognitionConfidence,
    this.fit,
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

  /// The raw freehand points captured before the most recent shape snap.
  /// Preserved so [revertLastSnap] can restore the original drawing.
  List<Offset>? originalPoints;

  /// Confidence (0.0–1.0) of the most recent shape recognition for this
  /// stroke. Null when the stroke has never been recognized or when
  /// shape assist is disabled.
  double? recognitionConfidence;

  /// Canonical shape parameters, so the painter can regenerate crisp
  /// geometry at any size (resizable). Null for freehand strokes.
  ShapeFit? fit;
}

/// Handle shown on a selected perfect shape for interactive resize.
enum ResizeHandleType { nw, n, ne, w, center, e, sw, s, se }

/// A single resize handle on a selected shape.
class ResizeHandle {
  const ResizeHandle({required this.position, required this.type});

  final Offset position;
  final ResizeHandleType type;
}

/// Controller for doodle drawing state.
///
/// Manages strokes, undo/redo, tool/color/width selection, shape recognition
/// with a revertible "snap," and a cached baked-picture of committed strokes
/// so drawing performance doesn't degrade as a doodle grows (see [_rebake]).
class DoodleController extends ChangeNotifier {
  DoodleController({
    Color defaultColor = Colors.black,
    bool shapeAssistEnabled = true,
  })  : _currentColor = defaultColor,
        _shapeAssistEnabled = shapeAssistEnabled;

  final List<Stroke> _strokes = [];
  final List<Stroke> _redoStack = [];
  Stroke? _activeStroke;

  DoodleTool _currentTool = DoodleTool.pen;
  DoodleTool _previousNonEraserTool = DoodleTool.pen;
  bool _stylusOnlyMode = false;
  bool _rulerEnabled = false;
  Offset _rulerOrigin = Offset.zero;
  double _rulerAngle = 0;

  /// Lasso select state.
  bool _lassoActive = false;
  List<Offset> _lassoPoints = [];
  Set<int> _selectedStrokeIndices = {};
  late Color _currentColor;
  double _currentWidth = 4.0;
  DoodleBackground _background = DoodleBackground.dotted;
  bool _isDrawing = false;
  bool _shapeAssistEnabled;

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

  // Draw-and-hold live shape snap state (Samsung Notes signature interaction).
  bool _isHoldSnapped = false;
  Offset? _holdAnchor;
  RecognizedShape? _holdShapeType;
  Offset? _holdCenter;
  double _holdInitialDistance = 1.0;
  List<Offset> _holdBasePoints = const [];

  // Shape selection state for post-snap resize / restore.
  int? _selectedStrokeIndex;
  bool _aspectLockEnabled = false;

  /// Increments on every stroke mutation so the painter can detect changes
  /// even though the Stroke object is mutated in place.
  int _activeStrokeVersion = 0;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  Stroke? get activeStroke => _activeStroke;
  int get activeStrokeVersion => _activeStrokeVersion;
  Picture? get bakedPicture => _bakedPicture;
  DoodleTool get currentTool => _currentTool;
  Color get currentColor => _currentColor;
  double get currentWidth => _currentWidth;
  DoodleBackground get background => _background;
  bool get isDrawing => _isDrawing;
  bool get shapeAssistEnabled => _shapeAssistEnabled;
  bool get isHoldSnapped => _isHoldSnapped;
  bool get canUndo => _strokes.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// True right after a shape snap fires — UI can show a transient
  /// "Shape recognized · tap to undo" affordance while this is true.
  bool get hasPendingSnapToUndo => _lastSnappedStroke != null;

  /// True when a mid-confidence shape match is waiting for user confirmation.
  bool get hasPendingSuggestion => _pendingSuggestion != null;

  /// The pending suggestion's recognized shape, for the UI to display.
  RecognizedShape? get pendingSuggestionShape => _pendingSuggestion?.shape;

  /// The currently selected stroke, or null if nothing is selected.
  Stroke? get selectedStroke =>
      _selectedStrokeIndex != null && _selectedStrokeIndex! < _strokes.length
          ? _strokes[_selectedStrokeIndex!]
          : null;

  /// True when a shape is currently selected for resize / restore.
  bool get isShapeSelected => _selectedStrokeIndex != null;

  /// When true, corner/edge drags preserve the shape's aspect ratio.
  bool get aspectLockEnabled => _aspectLockEnabled;

  void toggleShapeAssist() {
    _shapeAssistEnabled = !_shapeAssistEnabled;
    notifyListeners();
  }

  void toggleAspectLock() {
    _aspectLockEnabled = !_aspectLockEnabled;
    notifyListeners();
  }

  /// Selects the stroke at [index] for resize / restore. Clears any previous
  /// selection. Out-of-range indices are ignored.
  void selectStroke(int index) {
    if (index < 0 || index >= _strokes.length) {
      _selectedStrokeIndex = null;
      notifyListeners();
      return;
    }
    _selectedStrokeIndex = index;
    notifyListeners();
  }

  /// Clears the current selection without modifying any stroke.
  void deselect() {
    if (_selectedStrokeIndex == null) return;
    _selectedStrokeIndex = null;
    notifyListeners();
  }

  /// Reverts the selected perfect shape back to its original freehand points
  /// and clears the selection. No-op when nothing is selected.
  void restoreFreehand() {
    final stroke = selectedStroke;
    if (stroke == null) return;

    if (stroke.originalPoints != null) {
      stroke.points =
          stroke.originalPoints!.map((p) => StrokePoint(p)).toList();
    }
    stroke.isPerfectShape = false;
    stroke.shapeType = null;
    stroke.recognitionConfidence = null;
    stroke.fit = null;
    _selectedStrokeIndex = null;
    _rebake();
    notifyListeners();
  }

  /// Returns resize handles for the selected perfect shape, or an empty list
  /// when nothing is selected or the selected stroke is not a perfect shape.
  ///
  /// Handles are placed at the 4 corners, 4 edge midpoints, and center of the
  /// shape's bounding box.
  List<ResizeHandle> getResizeHandles() {
    final stroke = selectedStroke;
    if (stroke == null || !stroke.isPerfectShape || stroke.fit == null) {
      return const [];
    }

    final geometry = stroke.fit!.generatePoints(
      const Size(double.infinity, double.infinity),
      minRenderSize: _minRenderSize,
    );
    if (geometry.isEmpty) return const [];

    // Compute bounding box of the geometry.
    double minX = geometry.first.dx, maxX = geometry.first.dx;
    double minY = geometry.first.dy, maxY = geometry.first.dy;
    for (final p in geometry) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);

    return [
      ResizeHandle(position: Offset(minX, minY), type: ResizeHandleType.nw),
      ResizeHandle(position: Offset(center.dx, minY), type: ResizeHandleType.n),
      ResizeHandle(position: Offset(maxX, minY), type: ResizeHandleType.ne),
      ResizeHandle(position: Offset(minX, center.dy), type: ResizeHandleType.w),
      ResizeHandle(position: center, type: ResizeHandleType.center),
      ResizeHandle(position: Offset(maxX, center.dy), type: ResizeHandleType.e),
      ResizeHandle(position: Offset(minX, maxY), type: ResizeHandleType.sw),
      ResizeHandle(position: Offset(center.dx, maxY), type: ResizeHandleType.s),
      ResizeHandle(position: Offset(maxX, maxY), type: ResizeHandleType.se),
    ];
  }

  /// Returns the resize handle at [point] within [handleRadius], or null.
  ResizeHandle? hitTestResizeHandle(Offset point,
      {double handleRadius = 12.0}) {
    for (final handle in getResizeHandles()) {
      if ((handle.position - point).distance <= handleRadius) {
        return handle;
      }
    }
    return null;
  }

  /// Drags the selected shape's [handle] from its current position to
  /// [newPosition], updating the fit parameters in place.
  ///
  /// Corner/edge drags resize the bounding box; the center handle translates
  /// the shape. When [aspectLockEnabled] is true, corner drags preserve the
  /// aspect ratio.
  void resizeDrag(Offset handlePosition, Offset newPosition) {
    final stroke = selectedStroke;
    if (stroke == null || !stroke.isPerfectShape || stroke.fit == null) {
      return;
    }

    final handle = hitTestResizeHandle(handlePosition);
    if (handle == null) return;

    final fit = stroke.fit!;
    final geometry = fit.generatePoints(
      const Size(double.infinity, double.infinity),
      minRenderSize: _minRenderSize,
    );
    if (geometry.isEmpty) return;

    double minX = geometry.first.dx, maxX = geometry.first.dx;
    double minY = geometry.first.dy, maxY = geometry.first.dy;
    for (final p in geometry) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    switch (handle.type) {
      case ResizeHandleType.center:
        final delta = newPosition - handlePosition;
        stroke.fit = _translateFit(fit, delta);
        break;
      case ResizeHandleType.nw:
        // Drag top-left corner: minX/minY move with cursor; maxX/maxY fixed.
        if (fit is RectFit) {
          _applyCornerResize(
              stroke, fit, newPosition.dx, maxX, newPosition.dy, maxY);
        } else if (fit is OvalFit) {
          _applyCornerResizeOval(
              stroke, fit, newPosition.dx, maxX, newPosition.dy, maxY);
        }
        break;
      case ResizeHandleType.ne:
        if (fit is RectFit) {
          _applyCornerResize(
              stroke, fit, minX, newPosition.dx, newPosition.dy, maxY);
        } else if (fit is OvalFit) {
          _applyCornerResizeOval(
              stroke, fit, minX, newPosition.dx, newPosition.dy, maxY);
        }
        break;
      case ResizeHandleType.sw:
        if (fit is RectFit) {
          _applyCornerResize(
              stroke, fit, newPosition.dx, maxX, minY, newPosition.dy);
        } else if (fit is OvalFit) {
          _applyCornerResizeOval(
              stroke, fit, newPosition.dx, maxX, minY, newPosition.dy);
        }
        break;
      case ResizeHandleType.se:
        if (fit is RectFit) {
          _applyCornerResize(
              stroke, fit, minX, newPosition.dx, minY, newPosition.dy);
        } else if (fit is OvalFit) {
          _applyCornerResizeOval(
              stroke, fit, minX, newPosition.dx, minY, newPosition.dy);
        }
        break;
      case ResizeHandleType.n:
        if (fit is RectFit) {
          _applyEdgeResize(stroke, fit, minX, maxX, newPosition.dy, maxY);
        } else if (fit is OvalFit) {
          _applyEdgeResize(stroke, fit, minX, maxX, newPosition.dy, maxY);
        }
        break;
      case ResizeHandleType.s:
        if (fit is RectFit) {
          _applyEdgeResize(stroke, fit, minX, maxX, minY, newPosition.dy);
        } else if (fit is OvalFit) {
          _applyEdgeResize(stroke, fit, minX, maxX, minY, newPosition.dy);
        }
        break;
      case ResizeHandleType.w:
        if (fit is RectFit) {
          _applyEdgeResize(stroke, fit, newPosition.dx, maxX, minY, maxY);
        } else if (fit is OvalFit) {
          _applyEdgeResize(stroke, fit, newPosition.dx, maxX, minY, maxY);
        }
        break;
      case ResizeHandleType.e:
        if (fit is RectFit) {
          _applyEdgeResize(stroke, fit, minX, newPosition.dx, minY, maxY);
        } else if (fit is OvalFit) {
          _applyEdgeResize(stroke, fit, minX, newPosition.dx, minY, maxY);
        }
        break;
    }

    _activeStrokeVersion++;
    notifyListeners();
  }

  ShapeFit _translateFit(ShapeFit fit, Offset delta) {
    if (fit is RectFit) {
      return RectFit(
        center: fit.center + delta,
        uAxis: fit.uAxis,
        vAxis: fit.vAxis,
        halfWidth: fit.halfWidth,
        halfHeight: fit.halfHeight,
      );
    }
    if (fit is OvalFit) {
      return OvalFit(
        center: fit.center + delta,
        rx: fit.rx,
        ry: fit.ry,
      );
    }
    if (fit is TriangleFit) {
      return TriangleFit(
        a: fit.a + delta,
        b: fit.b + delta,
        c: fit.c + delta,
      );
    }
    if (fit is StarFit) {
      return StarFit(center: fit.center + delta, outerRadius: fit.outerRadius);
    }
    if (fit is LineFit) {
      return LineFit(start: fit.start + delta, end: fit.end + delta);
    }
    return fit;
  }

  void _applyCornerResize(Stroke stroke, RectFit fit, double newMinX,
      double newMaxX, double newMinY, double newMaxY) {
    final newW = (newMaxX - newMinX).clamp(_minRenderSize, double.infinity);
    final newH = (newMaxY - newMinY).clamp(_minRenderSize, double.infinity);
    final newCenter = Offset((newMinX + newMaxX) / 2, (newMinY + newMaxY) / 2);
    stroke.fit = RectFit(
      center: newCenter,
      uAxis: const Offset(1, 0),
      vAxis: const Offset(0, 1),
      halfWidth: newW / 2,
      halfHeight: newH / 2,
    );
  }

  void _applyCornerResizeOval(Stroke stroke, OvalFit fit, double newMinX,
      double newMaxX, double newMinY, double newMaxY) {
    final newW = (newMaxX - newMinX).clamp(_minRenderSize, double.infinity);
    final newH = (newMaxY - newMinY).clamp(_minRenderSize, double.infinity);
    final newCenter = Offset((newMinX + newMaxX) / 2, (newMinY + newMaxY) / 2);
    stroke.fit = OvalFit(
      center: newCenter,
      rx: newW / 2,
      ry: newH / 2,
    );
  }

  void _applyEdgeResize(Stroke stroke, ShapeFit fit, double newMinX,
      double newMaxX, double newMinY, double newMaxY) {
    final newW = (newMaxX - newMinX).clamp(_minRenderSize, double.infinity);
    final newH = (newMaxY - newMinY).clamp(_minRenderSize, double.infinity);
    final newCenter = Offset((newMinX + newMaxX) / 2, (newMinY + newMaxY) / 2);

    if (fit is RectFit) {
      stroke.fit = RectFit(
        center: newCenter,
        uAxis: const Offset(1, 0),
        vAxis: const Offset(0, 1),
        halfWidth: newW / 2,
        halfHeight: newH / 2,
      );
    } else if (fit is OvalFit) {
      stroke.fit = OvalFit(
        center: newCenter,
        rx: newW / 2,
        ry: newH / 2,
      );
    }
  }

  void setCurrentTool(DoodleTool tool) {
    if (_currentTool != DoodleTool.eraser) {
      _previousNonEraserTool = _currentTool;
    }
    _currentTool = tool;
    notifyListeners();
  }

  /// Toggle between the eraser and the previous non-eraser tool (pen by
  /// default), invoked by the stylus barrel button or a double-tap.
  void swapTool() {
    _currentTool = _currentTool == DoodleTool.eraser
        ? _previousNonEraserTool
        : DoodleTool.eraser;
    notifyListeners();
  }

  /// Whether the canvas rejects touch input and draws only with the stylus.
  bool get stylusOnlyMode => _stylusOnlyMode;

  /// Toggle between stylus-only and finger-friendly input.
  void toggleStylusOnlyMode() {
    _stylusOnlyMode = !_stylusOnlyMode;
    notifyListeners();
  }

  /// Whether the ruler/straightedge is active.
  bool get rulerEnabled => _rulerEnabled;

  /// Origin point of the ruler line.
  Offset get rulerOrigin => _rulerOrigin;
  set rulerOrigin(Offset value) {
    _rulerOrigin = value;
    notifyListeners();
  }

  /// Angle of the ruler line in radians.
  double get rulerAngle => _rulerAngle;
  set rulerAngle(double value) {
    _rulerAngle = value;
    notifyListeners();
  }

  void toggleRuler() {
    _rulerEnabled = !_rulerEnabled;
    notifyListeners();
  }

  /// Toggle lasso select mode on/off.
  void toggleLasso() {
    _lassoActive = !_lassoActive;
    if (!_lassoActive) {
      _lassoPoints = [];
      _selectedStrokeIndices.clear();
    }
    notifyListeners();
  }

  /// Project [point] onto the ruler line defined by [_rulerOrigin] and
  /// [_rulerAngle]. When ruler mode is off, returns [point] unchanged.
  Offset projectPointOntoRuler(Offset point) {
    if (!_rulerEnabled) return point;
    final u = Offset(math.cos(_rulerAngle), math.sin(_rulerAngle));
    final v = point - _rulerOrigin;
    final t = v.dx * u.dx + v.dy * u.dy;
    return _rulerOrigin + u * t;
  }

  /// Ray-casting point-in-polygon test for [point] against [_lassoPoints].
  bool pointInPolygon(Offset point) {
    final poly = _lassoPoints;
    final n = poly.length;
    if (n < 3) return false;
    bool inside = false;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final pi = poly[i];
      final pj = poly[j];
      if ((pi.dy > point.dy) != (pj.dy > point.dy) &&
          point.dx <
              (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Whether lasso selection mode is active.
  bool get lassoActive => _lassoActive;

  /// Current lasso polygon points.
  List<Offset> get lassoPoints => List.unmodifiable(_lassoPoints);
  set lassoPoints(List<Offset> value) {
    _lassoPoints = List<Offset>.from(value);
    notifyListeners();
  }

  /// Currently selected stroke indices.
  Set<int> get selectedStrokeIndices =>
      Set.unmodifiable(_selectedStrokeIndices);
  set selectedStrokeIndices(Set<int> value) {
    _selectedStrokeIndices = Set<int>.from(value);
    notifyListeners();
  }

  /// Begin a lasso selection at [point].
  void beginLasso(Offset point) {
    _lassoActive = true;
    _lassoPoints = [point];
    notifyListeners();
  }

  /// Extend the lasso polygon with [point].
  void extendLasso(Offset point) {
    if (!_lassoActive) return;
    _lassoPoints = [..._lassoPoints, point];
    notifyListeners();
  }

  /// End the lasso gesture and compute which strokes are inside the polygon.
  void endLasso() {
    if (!_lassoActive) return;
    _selectedStrokeIndices = {};
    for (var i = 0; i < _strokes.length; i++) {
      final stroke = _strokes[i];
      if (stroke.points.any((p) => pointInPolygon(p.position))) {
        _selectedStrokeIndices.add(i);
      }
    }
    _lassoActive = false;
    _lassoPoints = [];
    notifyListeners();
  }

  /// Translate all selected strokes by [delta].
  void translateSelection(Offset delta) {
    for (final i in _selectedStrokeIndices) {
      final stroke = _strokes[i];
      stroke.points = stroke.points
          .map((p) => StrokePoint(p.position + delta, pressure: p.pressure))
          .toList();
    }
    _activeStrokeVersion++;
    notifyListeners();
  }

  /// Clear the current lasso selection.
  void clearLassoSelection() {
    _selectedStrokeIndices.clear();
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
    _isHoldSnapped = false;
    _holdAnchor = null;
    _holdShapeType = null;
    _holdCenter = null;
    _holdInitialDistance = 1.0;
    _holdBasePoints = const [];
    double opacity = 1.0;
    double actualWidth = _currentWidth;

    if (_currentTool == DoodleTool.highlighter) {
      opacity = 0.35;
      actualWidth = _currentWidth * 3.5;
    } else if (_currentTool == DoodleTool.eraser) {
      actualWidth = _currentWidth * 4.0;
    }

    _activeStroke = Stroke(
      points: [
        StrokePoint(
          _rulerEnabled ? projectPointOntoRuler(point) : point,
          pressure: pressure,
        ),
      ],
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
    _activeStrokeVersion++;
    notifyListeners();
  }

  void continueStroke(Offset point, {double pressure = 1.0}) {
    if (_activeStroke == null) return;
    final projected = _rulerEnabled ? projectPointOntoRuler(point) : point;
    _activeStroke!.points.add(StrokePoint(projected, pressure: pressure));
    _activeStrokeVersion++;
    notifyListeners();
  }

  /// Triggers live shape snap when the user pauses their pen at the end of a stroke
  /// (draw-and-hold interaction popularized by Samsung Notes and Apple Pencil).
  bool triggerHoldToSnap() {
    final active = _activeStroke;
    if (active == null || active.tool == DoodleTool.eraser) return false;
    if (active.points.length < 8) return false;

    final raw = active.points.map((p) => p.position).toList();
    final match = recognizeShape(raw);
    if (!match.isRecognized) return false;

    // Preserve the original freehand points before snapping.
    active.originalPoints = active.points.map((p) => p.position).toList();
    active.recognitionConfidence = match.confidence;
    active.fit = shapeFitFromMatch(match);

    _preSnapPoints = List.of(active.points);
    _holdAnchor = active.points.first.position;
    _holdShapeType = match.shape;
    _holdBasePoints = List.of(match.points);

    // Compute canonical center of the recognized shape
    double sumX = 0, sumY = 0;
    for (final p in match.points) {
      sumX += p.dx;
      sumY += p.dy;
    }
    final center = match.points.isNotEmpty
        ? Offset(sumX / match.points.length, sumY / match.points.length)
        : active.points.last.position;
    _holdCenter = center;

    // Compute distance from center to where user paused their touch
    final lastTouch = active.points.last.position;
    _holdInitialDistance = math.max(16.0, (lastTouch - center).distance);

    _isHoldSnapped = true;

    active.points = match.points.map((p) => StrokePoint(p)).toList();
    active.isPerfectShape = true;
    active.shapeType = match.shape;
    _lastSnappedStroke = active;
    _activeStrokeVersion++;

    HapticFeedback.mediumImpact();
    notifyListeners();
    return true;
  }

  /// While holding down after a snap, moving the finger/stylus interactively
  /// resizes/transforms the snapped shape in real time.
  void updateHoldSnappedStroke(Offset currentPoint) {
    final active = _activeStroke;
    if (active == null || !_isHoldSnapped) return;

    final shape = _holdShapeType;

    switch (shape) {
      case RecognizedShape.line:
      case RecognizedShape.arrow:
        final anchor = _holdAnchor ?? active.points.first.position;
        final snappedEnd = snapLineAngle(anchor, currentPoint);
        active.points = [StrokePoint(anchor), StrokePoint(snappedEnd)];
      case RecognizedShape.rectangle:
      case RecognizedShape.oval:
      case RecognizedShape.triangle:
      case RecognizedShape.star:
        if (_holdCenter != null && _holdBasePoints.isNotEmpty) {
          final center = _holdCenter!;
          final currentDist = (currentPoint - center).distance;
          final scale = (currentDist / _holdInitialDistance).clamp(0.15, 6.0);
          active.points = _holdBasePoints
              .map((p) => StrokePoint(center + (p - center) * scale))
              .toList();
        } else if (_holdAnchor != null) {
          final rect = Rect.fromPoints(_holdAnchor!, currentPoint);
          active.points = [
            StrokePoint(rect.topLeft),
            StrokePoint(rect.topRight),
            StrokePoint(rect.bottomRight),
            StrokePoint(rect.bottomLeft),
            StrokePoint(rect.topLeft),
          ];
        }
      default:
        break;
    }

    // Re-recognize the resized stroke so confidence stays current.
    final raw = active.points.map((p) => p.position).toList();
    if (raw.length >= 2) {
      final match = recognizeShape(raw);
      if (match.isRecognized) {
        active.recognitionConfidence = match.confidence;
        active.fit = shapeFitFromMatch(match);
        active.shapeType = match.shape;
      }
    }

    _activeStrokeVersion++;
    notifyListeners();
  }

  void endStroke() {
    if (_activeStroke == null) return;
    // Always attempt recognition on stroke end — recognition is not gated
    // by whether a hold snap already fired. This lets a resized hold-snap
    // be re-recognized to its final shape.
    if (_shapeAssistEnabled) {
      _attemptShapeSnap();
    }
    _isHoldSnapped = false;
    _holdAnchor = null;
    _holdShapeType = null;
    _holdCenter = null;
    _holdInitialDistance = 1.0;
    _holdBasePoints = const [];
    _activeStroke = null;
    _isDrawing = false;
    _rebake();
    notifyListeners();
  }

  /// Discards the in-progress stroke without committing it to the canvas.
  void cancelStroke() {
    if (_activeStroke == null) return;
    _strokes.remove(_activeStroke);
    _isHoldSnapped = false;
    _holdAnchor = null;
    _holdShapeType = null;
    _holdCenter = null;
    _holdInitialDistance = 1.0;
    _holdBasePoints = const [];
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

    // Preserve the original freehand points before snapping.
    active.originalPoints = active.points.map((p) => p.position).toList();
    active.recognitionConfidence = match.confidence;
    active.fit = shapeFitFromMatch(match);

    _preSnapPoints = List.of(active.points);

    if (match.confidence >= 0.60) {
      // High confidence: commit immediately with haptic feedback.
      active.points = match.points.map((p) => StrokePoint(p)).toList();
      active.isPerfectShape = true;
      active.shapeType = match.shape;
      _lastSnappedStroke = active;
      HapticFeedback.mediumImpact();
    } else if (match.confidence >= 0.40) {
      // Ambiguous: stash as a pending suggestion.
      _pendingSuggestion = match;
      _pendingSuggestionStroke = active;
      HapticFeedback.selectionClick();
    }
  }

  /// Reverts the most recent shape snap back to the original hand-drawn
  /// points. Call this from a "tap to undo" chip shown while
  /// [hasPendingSnapToUndo] is true.
  void revertLastSnap() {
    final stroke = _lastSnappedStroke;
    if (stroke == null) return;

    // Prefer stroke.originalPoints (List<Offset>), fall back to
    // _preSnapPoints (List<StrokePoint>) for backward compatibility.
    if (stroke.originalPoints != null) {
      stroke.points =
          stroke.originalPoints!.map((p) => StrokePoint(p)).toList();
    } else if (_preSnapPoints != null) {
      stroke.points = List.of(_preSnapPoints!);
    } else {
      return;
    }
    stroke.isPerfectShape = false;
    stroke.shapeType = null;
    stroke.recognitionConfidence = null;
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

  /// Adds a single stroke to the document.
  void addStroke(Stroke stroke) {
    _strokes.add(stroke);
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
