import 'dart:math' as math;
import 'dart:ui';

import 'doodle_shape_recognizer.dart';

/// Canonical parameters for a recognized shape, so it can be regenerated at
/// any size (resizable) instead of being locked to baked points.
///
/// Store [ShapeFit] on [Stroke.fit]; the painter regenerates crisp geometry
/// from these parameters at render time, clamped to [minRenderSize] so the
/// shape is never too small to verify.
sealed class ShapeFit {
  const ShapeFit();

  /// Regenerate geometry points that fill [targetSize], clamped so no
  /// dimension falls below [minRenderSize].
  List<Offset> generatePoints(Size targetSize, {double minRenderSize = 40.0});
}

/// A straight line or arrow: two endpoints.
class LineFit extends ShapeFit {
  const LineFit({required this.start, required this.end});

  final Offset start;
  final Offset end;

  @override
  List<Offset> generatePoints(Size targetSize, {double minRenderSize = 40.0}) {
    final p1 = Offset(start.dx, start.dy);
    final p2 = Offset(end.dx, end.dy);
    final bounds = Rect.fromPoints(p1, p2);
    final w = bounds.width;
    final h = bounds.height;
    final scaleX = w > 0 && w < minRenderSize ? minRenderSize / w : 1.0;
    final scaleY = h > 0 && h < minRenderSize ? minRenderSize / h : 1.0;
    final scale = math.max(scaleX, scaleY);
    if (scale == 1.0) return [p1, p2];
    final center = bounds.center;
    return [
      center + (p1 - center) * scale,
      center + (p2 - center) * scale,
    ];
  }
}

/// A rectangle / square, possibly rotated: center + two unit axes + half
/// extents. Produces a closed 5-point loop.
class RectFit extends ShapeFit {
  const RectFit({
    required this.center,
    required this.uAxis,
    required this.vAxis,
    required this.halfWidth,
    required this.halfHeight,
  });

  final Offset center;
  final Offset uAxis; // unit vector along the long edge
  final Offset vAxis; // unit vector perpendicular
  final double halfWidth;
  final double halfHeight;

  List<Offset> _corners() {
    return [
      center - uAxis * halfWidth - vAxis * halfHeight,
      center + uAxis * halfWidth - vAxis * halfHeight,
      center + uAxis * halfWidth + vAxis * halfHeight,
      center - uAxis * halfWidth + vAxis * halfHeight,
    ];
  }

  @override
  List<Offset> generatePoints(Size targetSize, {double minRenderSize = 40.0}) {
    final corners = _corners();
    final xs = corners.map((p) => p.dx).toList();
    final ys = corners.map((p) => p.dy).toList();
    final bounds = Rect.fromLTRB(
      xs.reduce(math.min), ys.reduce(math.min),
      xs.reduce(math.max), ys.reduce(math.max),
    );
    final w = bounds.width;
    final h = bounds.height;
    final scaleX = w > 0 && w < minRenderSize ? minRenderSize / w : 1.0;
    final scaleY = h > 0 && h < minRenderSize ? minRenderSize / h : 1.0;
    final scale = math.max(scaleX, scaleY);
    if (scale == 1.0) return [...corners, corners.first];
    return corners
        .map((p) => center + (p - center) * scale)
        .toList()
      ..add(center + (corners.first - center) * scale);
  }
}

/// An oval / circle: center + x-radius + y-radius.
class OvalFit extends ShapeFit {
  const OvalFit({
    required this.center,
    required this.rx,
    required this.ry,
  });

  final Offset center;
  final double rx;
  final double ry;

  @override
  List<Offset> generatePoints(Size targetSize, {double minRenderSize = 40.0}) {
    final effectiveRx = math.max(rx, minRenderSize / 2);
    final effectiveRy = math.max(ry, minRenderSize / 2);
    return [
      for (int i = 0; i <= 60; i++)
        Offset(
          center.dx + effectiveRx * math.cos((i / 60) * math.pi * 2),
          center.dy + effectiveRy * math.sin((i / 60) * math.pi * 2),
        ),
    ];
  }
}

/// A triangle: three vertices + closed loop.
class TriangleFit extends ShapeFit {
  const TriangleFit({required this.a, required this.b, required this.c});

  final Offset a;
  final Offset b;
  final Offset c;

  @override
  List<Offset> generatePoints(Size targetSize, {double minRenderSize = 40.0}) {
    final pts = [a, b, c];
    final xs = pts.map((p) => p.dx).toList();
    final ys = pts.map((p) => p.dy).toList();
    final bounds = Rect.fromLTRB(
      xs.reduce(math.min), ys.reduce(math.min),
      xs.reduce(math.max), ys.reduce(math.max),
    );
    final w = bounds.width;
    final h = bounds.height;
    final scaleX = w > 0 && w < minRenderSize ? minRenderSize / w : 1.0;
    final scaleY = h > 0 && h < minRenderSize ? minRenderSize / h : 1.0;
    final scale = math.max(scaleX, scaleY);
    if (scale == 1.0) return [...pts, pts.first];
    final center = bounds.center;
    return pts.map((p) => center + (p - center) * scale).toList()
      ..add(center + (pts.first - center) * scale);
  }
}

/// A 5-point star: center + outer radius.
class StarFit extends ShapeFit {
  const StarFit({required this.center, required this.outerRadius});

  final Offset center;
  final double outerRadius;

  @override
  List<Offset> generatePoints(Size targetSize, {double minRenderSize = 40.0}) {
    final effectiveR = math.max(outerRadius, minRenderSize / 2);
    final innerR = effectiveR * 0.40;
    const startAngle = -math.pi / 2;
    final pts = <Offset>[];
    for (int i = 0; i < 10; i++) {
      final angle = startAngle + (i * math.pi / 5);
      final r = (i % 2 == 0) ? effectiveR : innerR;
      pts.add(center + Offset(math.cos(angle) * r, math.sin(angle) * r));
    }
    pts.add(pts.first);
    return pts;
  }
}

/// No shape (freehand stroke).
class NoneFit extends ShapeFit {
  const NoneFit();

  @override
  List<Offset> generatePoints(Size targetSize, {double minRenderSize = 40.0}) {
    return [];
  }
}

/// Converts a [ShapeMatch] into the corresponding [ShapeFit] so the painter
/// can regenerate crisp geometry at any size. Returns null for [none].
ShapeFit? shapeFitFromMatch(ShapeMatch match) {
  switch (match.shape) {
    case RecognizedShape.none:
      return const NoneFit();
    case RecognizedShape.line:
      if (match.points.length >= 2) {
        return LineFit(start: match.points.first, end: match.points.last);
      }
      return null;
    case RecognizedShape.arrow:
      if (match.points.length >= 2) {
        return LineFit(start: match.points.first, end: match.points.last);
      }
      return null;
    case RecognizedShape.rectangle:
      if (match.points.length >= 4) {
        final pts = match.points.sublist(0, 4);
        final xs = pts.map((p) => p.dx).toList();
        final ys = pts.map((p) => p.dy).toList();
        final minX = xs.reduce(math.min);
        final maxX = xs.reduce(math.max);
        final minY = ys.reduce(math.min);
        final maxY = ys.reduce(math.max);
        final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
        // Estimate the dominant edge direction from the first two corners.
        final u = Offset((pts[1].dx - pts[0].dx), (pts[1].dy - pts[0].dy));
        final uLen = u.distance;
        final uAxis = uLen > 0 ? Offset(u.dx / uLen, u.dy / uLen) : const Offset(1, 0);
        final vAxis = Offset(-uAxis.dy, uAxis.dx);
        final halfW = ((pts[1].dx - pts[0].dx).abs() + (pts[2].dx - pts[1].dx).abs()) / 4;
        final halfH = ((pts[2].dy - pts[1].dy).abs() + (pts[3].dy - pts[2].dy).abs()) / 4;
        return RectFit(
          center: center,
          uAxis: uAxis,
          vAxis: vAxis,
          halfWidth: halfW > 0 ? halfW : (maxX - minX) / 2,
          halfHeight: halfH > 0 ? halfH : (maxY - minY) / 2,
        );
      }
      return null;
    case RecognizedShape.oval:
      if (match.points.isNotEmpty) {
        double minX = match.points.first.dx, maxX = match.points.first.dx;
        double minY = match.points.first.dy, maxY = match.points.first.dy;
        for (final p in match.points) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
        final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
        return OvalFit(
          center: center,
          rx: (maxX - minX) / 2,
          ry: (maxY - minY) / 2,
        );
      }
      return null;
    case RecognizedShape.triangle:
      if (match.points.length >= 3) {
        return TriangleFit(
          a: match.points[0],
          b: match.points[1],
          c: match.points[2],
        );
      }
      return null;
    case RecognizedShape.star:
      if (match.points.isNotEmpty) {
        double minX = match.points.first.dx, maxX = match.points.first.dx;
        double minY = match.points.first.dy, maxY = match.points.first.dy;
        for (final p in match.points) {
          if (p.dx < minX) minX = p.dx;
          if (p.dx > maxX) maxX = p.dx;
          if (p.dy < minY) minY = p.dy;
          if (p.dy > maxY) maxY = p.dy;
        }
        final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
        final outerR = math.min(maxX - minX, maxY - minY) / 2;
        return StarFit(center: center, outerRadius: outerR);
      }
      return null;
  }
}
