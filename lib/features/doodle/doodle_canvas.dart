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
  });

  final DoodleController controller;

  /// Key for the internal [RepaintBoundary] (used for thumbnail capture).
  final GlobalKey? boundaryKey;

  /// Optional note-specific color scheme for themed grid lines and background.
  final ColorScheme? noteScheme;

  /// Called when the user pans with two or more pointers (used to scroll the
  /// infinite canvas). [deltaY] is positive when the fingers move downward.
  final ValueChanged<double>? onTwoFingerPan;

  @override
  State<DoodleCanvas> createState() => _DoodleCanvasState();
}

class _DoodleCanvasState extends State<DoodleCanvas> {
  final Map<int, Offset> _activePointers = {};
  Offset _lastFocalDelta = Offset.zero;
  bool _multiTouch = false;

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
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() => setState(() {});

  Offset _focalPoint() {
    final points = _activePointers.values.toList();
    if (points.isEmpty) return Offset.zero;
    return points.reduce((a, b) => a + b) / points.length.toDouble();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length >= 2) {
      _multiTouch = true;
      widget.controller.cancelStroke();
      _lastFocalDelta = _focalPoint();
      return;
    }
    _lastFocalDelta = event.localPosition;
    widget.controller
        .startStroke(event.localPosition, pressure: event.pressure);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_multiTouch) {
      final focal = _focalPoint();
      final delta = focal - _lastFocalDelta;
      _lastFocalDelta = focal;
      widget.controller.cancelStroke();
      widget.onTwoFingerPan?.call(delta.dy);
      return;
    }
    widget.controller
        .continueStroke(event.localPosition, pressure: event.pressure);
  }

  void _handlePointerEnd(int pointer) {
    _activePointers.remove(pointer);
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
        child: CustomPaint(
          painter: _DoodlePainter(
            background: widget.controller.background,
            backgroundColor: gridColor,
            bakedPicture: widget.controller.bakedPicture,
            activeStroke: widget.controller.activeStroke,
            activeStrokeVersion: widget.controller.activeStrokeVersion,
          ),
          size: Size.infinite,
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
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) {
    return oldDelegate.bakedPicture != bakedPicture ||
        oldDelegate.activeStrokeVersion != activeStrokeVersion ||
        oldDelegate.background != background ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
