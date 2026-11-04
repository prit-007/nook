import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'doodle_controller.dart';
import 'doodle_painter.dart';

/// Full-screen drawing canvas that renders organic, pressure-sensitive
/// strokes via perfect_freehand and a selectable background template.
///
/// Background, committed strokes, and the active stroke are all painted by
/// one merged [_DoodlePainter] inside a single `saveLayer`/`restore` pair —
/// this is what makes the eraser's `BlendMode.clear` reveal the background
/// pattern predictably instead of depending on how Flutter happens to
/// composite separate CustomPaint layers.
class DoodleCanvas extends StatefulWidget {
  const DoodleCanvas({
    super.key,
    required this.controller,
    this.boundaryKey,
    this.noteScheme,
    this.onTwoFingerPan,
    this.onNearBottomEdge,
  });

  final DoodleController controller;

  /// Key for the internal [RepaintBoundary] (used for thumbnail capture).
  final GlobalKey? boundaryKey;

  /// Optional note-specific color scheme for themed grid lines and background.
  final ColorScheme? noteScheme;

  /// Called when the user pans with two or more pointers (used to scroll the
  /// infinite canvas). [deltaY] is positive when the fingers move downward.
  final ValueChanged<double>? onTwoFingerPan;

  /// Called when an active stroke approaches the bottom edge of the canvas,
  /// triggering auto-expansion of the paper height.
  final VoidCallback? onNearBottomEdge;

  @override
  State<DoodleCanvas> createState() => _DoodleCanvasState();
}

class _DoodleCanvasState extends State<DoodleCanvas> {
  final Map<int, Offset> _activePointers = {};
  Offset _lastFocalDelta = Offset.zero;
  bool _multiTouch = false;
  Timer? _holdSnapTimer;
  Offset? _lastHoldPosition;

  // Selection / resize state for post-snap shapes.
  bool _isResizing = false;
  ResizeHandle? _resizeHandle;
  Offset? _resizeStartPosition;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void didUpdateWidget(DoodleCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerUpdate);
      widget.controller.addListener(_onControllerUpdate);
    }
  }

  @override
  void dispose() {
    _holdSnapTimer?.cancel();
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() => setState(() {});

  void _scheduleHoldTimer(Offset position) {
    _holdSnapTimer?.cancel();
    if (!widget.controller.shapeAssistEnabled) return;
    _lastHoldPosition = position;
    _holdSnapTimer = Timer(const Duration(milliseconds: 440), () {
      if (!mounted) return;
      widget.controller.triggerHoldToSnap();
    });
  }

  Offset _focalPoint() {
    final points = _activePointers.values.toList();
    if (points.isEmpty) return Offset.zero;
    return points.reduce((a, b) => a + b) / points.length.toDouble();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length >= 2) {
      _holdSnapTimer?.cancel();
      _holdSnapTimer = null;
      _multiTouch = true;
      widget.controller.cancelStroke();
      _lastFocalDelta = _focalPoint();
      return;
    }
    _lastFocalDelta = event.localPosition;

    // Selection mode: no active stroke and a shape is already selected —
    // tapping a handle starts a resize drag, tapping elsewhere deselects.
    // When nothing is selected, always start drawing (current behavior).
    if (widget.controller.activeStroke == null &&
        !widget.controller.isHoldSnapped &&
        widget.controller.isShapeSelected) {
      final handle = widget.controller.hitTestResizeHandle(
        event.localPosition,
        handleRadius: 14.0,
      );
      if (handle != null) {
        _isResizing = true;
        _resizeHandle = handle;
        _resizeStartPosition = event.localPosition;
        _holdSnapTimer?.cancel();
        return;
      }

      // Tap on the selected shape keeps it selected; tap elsewhere deselects
      // and falls through to start a new stroke at the tap point.
      widget.controller.deselect();
    }

    widget.controller
        .startStroke(event.localPosition, pressure: event.pressure);
    _scheduleHoldTimer(event.localPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_multiTouch) {
      _holdSnapTimer?.cancel();
      _holdSnapTimer = null;
      final focal = _focalPoint();
      final delta = focal - _lastFocalDelta;
      _lastFocalDelta = focal;
      widget.controller.cancelStroke();
      widget.onTwoFingerPan?.call(delta.dy);
      return;
    }
    if (widget.controller.isHoldSnapped) {
      widget.controller.updateHoldSnappedStroke(event.localPosition);
      return;
    }

    // Resize drag: update the selected shape's fit parameters live.
    if (_isResizing && _resizeHandle != null) {
      widget.controller.resizeDrag(_resizeStartPosition!,
          event.localPosition);
      _resizeStartPosition = event.localPosition;
      return;
    }
    widget.controller
        .continueStroke(event.localPosition, pressure: event.pressure);

    // Auto-extend canvas when drawing near the bottom edge
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      if (event.localPosition.dy > box.size.height - 120) {
        widget.onNearBottomEdge?.call();
      }
    }

    if ((event.localPosition - (_lastHoldPosition ?? event.localPosition))
            .distance >
        12) {
      _scheduleHoldTimer(event.localPosition);
    }
  }

  void _handlePointerEnd(int pointer) {
    _holdSnapTimer?.cancel();
    _holdSnapTimer = null;
    _lastHoldPosition = null;
    _activePointers.remove(pointer);

    // End a resize drag.
    if (_isResizing) {
      _isResizing = false;
      _resizeHandle = null;
      _resizeStartPosition = null;
      return;
    }

    if (_multiTouch) {
      if (_activePointers.length < 2) {
        _multiTouch = false;
        _lastFocalDelta = Offset.zero;
      }
      return;
    }
    widget.controller.endStroke();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final noteScheme = widget.noteScheme;
    final baseGridColor = noteScheme?.outlineVariant ?? scheme.outlineVariant;
    final gridColor = baseGridColor.computeLuminance() < 0.2
        ? Colors.white.withValues(alpha: 0.2)
        : baseGridColor.withValues(alpha: 0.3);

    return RepaintBoundary(
      key: widget.boundaryKey,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: (event) => _handlePointerEnd(event.pointer),
        onPointerCancel: (event) => _handlePointerEnd(event.pointer),
        child: Stack(
          children: [
            CustomPaint(
              painter: _DoodlePainter(
                background: widget.controller.background,
                backgroundColor: gridColor,
                bakedPicture: widget.controller.bakedPicture,
                activeStroke: widget.controller.activeStroke,
                activeStrokeVersion: widget.controller.activeStrokeVersion,
              ),
              size: Size.infinite,
            ),
            // Selection handles overlay — painted on top of the drawing layer.
            if (widget.controller.isShapeSelected)
              CustomPaint(
                painter: _SelectionHandlesPainter(
                  handles: widget.controller.getResizeHandles(),
                  isResizing: _isResizing,
                  activeHandle: _resizeHandle,
                ),
                size: Size.infinite,
              ),
          ],
        ),
      ),
    );
  }
}

/// Merges background + committed (baked) strokes + the live active stroke
/// into one paint pass, wrapped in a single `saveLayer`/`restore` so an
/// eraser's `BlendMode.clear` is scoped to exactly this content — it reveals
/// the background pattern, not whatever happens to sit behind this widget
/// in the wider render tree.
class _DoodlePainter extends CustomPainter {
  _DoodlePainter({
    required this.background,
    required this.backgroundColor,
    required this.bakedPicture,
    required this.activeStroke,
    required this.activeStrokeVersion,
  });

  final DoodleBackground background;
  final Color backgroundColor;
  final Picture? bakedPicture;
  final Stroke? activeStroke;
  final int activeStrokeVersion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());

    paintDoodleBackground(canvas, size,
        background: background, color: backgroundColor);
    if (bakedPicture != null) canvas.drawPicture(bakedPicture!);
    if (activeStroke != null) {
      paintDoodleStrokes(canvas, size, [activeStroke!]);
    }

    canvas.restore();

    // Subtle eraser cursor indicator following the active touch/stylus
    if (activeStroke != null &&
        activeStroke!.tool == DoodleTool.eraser &&
        activeStroke!.points.isNotEmpty) {
      final pos = activeStroke!.points.last.position;
      final radius = activeStroke!.width * 1.5;
      final cursorPaint = Paint()
        ..color = (backgroundColor.computeLuminance() > 0.4
                ? Colors.black
                : Colors.white)
            .withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(pos, radius, cursorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) {
    return oldDelegate.bakedPicture != bakedPicture ||
        oldDelegate.activeStrokeVersion != activeStrokeVersion ||
        oldDelegate.background != background ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

/// Paints selection handles (corners, edges, center) around a selected
/// perfect shape so the user can resize it by dragging.
class _SelectionHandlesPainter extends CustomPainter {
  const _SelectionHandlesPainter({
    required this.handles,
    required this.isResizing,
    required this.activeHandle,
  });

  final List<ResizeHandle> handles;
  final bool isResizing;
  final ResizeHandle? activeHandle;

  static const double _handleRadius = 7.0;
  static const double _handleStrokeWidth = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = _handleStrokeWidth;

    for (final handle in handles) {
      final isActive = activeHandle != null &&
          handle.position == activeHandle!.position &&
          handle.type == activeHandle!.type;

      // Outer ring
      canvas.drawCircle(handle.position, _handleRadius + 2, strokePaint);
      // Inner fill
      canvas.drawCircle(
        handle.position,
        isActive ? _handleRadius : _handleRadius - 1,
        fillPaint,
      );
      // Center dot for active handle
      if (isActive) {
        final dotPaint = Paint()
          ..color = Colors.blueAccent
          ..style = PaintingStyle.fill;
        canvas.drawCircle(handle.position, 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionHandlesPainter oldDelegate) {
    return oldDelegate.handles != handles ||
        oldDelegate.isResizing != isResizing ||
        oldDelegate.activeHandle != activeHandle;
  }
}
