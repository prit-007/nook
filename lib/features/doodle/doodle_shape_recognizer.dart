import 'dart:math' as math;
import 'dart:ui';

/// Shapes the recognizer can snap a freehand stroke to.
enum RecognizedShape { none, line, arrow, triangle, rectangle, oval }

/// Result of attempting to recognize a shape from a raw stroke.
///
/// [points] is the clean, corrected geometry to render in place of the raw
/// hand-drawn points — never render [points] silently without giving the
/// user a way to revert (see `DoodleController.revertLastSnap`).
class ShapeMatch {
  const ShapeMatch(this.shape, this.points);

  final RecognizedShape shape;
  final List<Offset> points;

  bool get isRecognized => shape != RecognizedShape.none;
}

/// Recognizes a hand-drawn stroke as a line, arrow, triangle, rectangle
/// (including rotated ones), or oval — or returns [RecognizedShape.none] if
/// nothing matches confidently.
///
/// Approach: simplify the noisy raw path down to its essential corners via
/// Ramer–Douglas–Peucker, then classify by corner count + closedness, rather
/// than matching path-length ratios directly against raw points (which only
/// catches axis-aligned shapes and is fooled by drawing speed variance).
ShapeMatch recognizeShape(List<Offset> raw) {
  if (raw.length < 8) return const ShapeMatch(RecognizedShape.none, []);

  final first = raw.first;
  final last = raw.last;
  final bounds = _boundsOf(raw);
  final diagonal = Offset(bounds.width, bounds.height).distance;
  if (diagonal < 12) return const ShapeMatch(RecognizedShape.none, []);

  final closed = (last - first).distance < diagonal * 0.15;

  final simplified = _mergeCollinear(_simplifyRDP(raw, diagonal * 0.03));
  final cornerCount = closed ? simplified.length - 1 : simplified.length;

  // --- Open path: line or arrow ---
  if (!closed && cornerCount <= 2) {
    final tailIndex = (raw.length * 0.85).floor().clamp(0, raw.length - 2);
    final tailVec = last - raw[tailIndex];
    final shaftVec = last - first;
    final bendDeg = _angleBetweenDeg(tailVec, shaftVec);
    if (bendDeg > 25 && bendDeg < 155) {
      return ShapeMatch(RecognizedShape.arrow, [first, last]);
    }
    return ShapeMatch(RecognizedShape.line, [first, last]);
  }

  // --- Closed path: triangle ---
  if (closed && cornerCount == 3) {
    return ShapeMatch(
      RecognizedShape.triangle,
      [...simplified.take(3), simplified.first],
    );
  }

  // --- Closed path: rectangle (rotated-aware) ---
  if (closed && cornerCount == 4) {
    return ShapeMatch(
      RecognizedShape.rectangle,
      _fitRotatedRectangle(simplified.take(4).toList()),
    );
  }

  // --- Closed path: oval / circle ---
  if (closed) {
    final centroid = _centroidOf(raw);
    final radii = raw.map((p) => (p - centroid).distance).toList();
    final meanR = radii.reduce((a, b) => a + b) / radii.length;
    if (meanR < 1) return const ShapeMatch(RecognizedShape.none, []);
    final variance =
        radii.map((r) => math.pow(r - meanR, 2)).reduce((a, b) => a + b) /
            radii.length;
    final coeffOfVariation = math.sqrt(variance) / meanR;
    if (coeffOfVariation < 0.25) {
      return ShapeMatch(RecognizedShape.oval, _generateOvalFromBounds(bounds));
    }
  }

  return const ShapeMatch(RecognizedShape.none, []);
}

// --- Geometry helpers ---

/// Ramer–Douglas–Peucker polyline simplification: collapses a noisy stroke
/// down to the minimal set of points that still traces its essential shape.
List<Offset> _simplifyRDP(List<Offset> points, double epsilon) {
  if (points.length < 3) return points;

  double maxDist = 0;
  int index = 0;
  final start = points.first;
  final end = points.last;

  for (int i = 1; i < points.length - 1; i++) {
    final dist = _perpendicularDistance(points[i], start, end);
    if (dist > maxDist) {
      maxDist = dist;
      index = i;
    }
  }

  if (maxDist > epsilon) {
    final left = _simplifyRDP(points.sublist(0, index + 1), epsilon);
    final right = _simplifyRDP(points.sublist(index), epsilon);
    return [...left.sublist(0, left.length - 1), ...right];
  }
  return [start, end];
}

double _perpendicularDistance(Offset p, Offset lineStart, Offset lineEnd) {
  final dx = lineEnd.dx - lineStart.dx;
  final dy = lineEnd.dy - lineStart.dy;
  final lengthSq = dx * dx + dy * dy;
  if (lengthSq == 0) return (p - lineStart).distance;
  final t =
      ((p.dx - lineStart.dx) * dx + (p.dy - lineStart.dy) * dy) / lengthSq;
  final proj = Offset(lineStart.dx + t * dx, lineStart.dy + t * dy);
  return (p - proj).distance;
}

/// Merges consecutive vertices whose turn angle is too shallow to be a real
/// corner — this is what stops ordinary hand-wobble from being counted as
/// extra corners and misclassifying a rough circle as a hexagon.
List<Offset> _mergeCollinear(List<Offset> pts, {double minTurnDeg = 20}) {
  if (pts.length < 3) return pts;
  final result = <Offset>[pts.first];
  for (int i = 1; i < pts.length - 1; i++) {
    final a = result.last;
    final b = pts[i];
    final c = pts[i + 1];
    final turnDeg = _angleBetweenDeg(b - a, c - b);
    if (turnDeg > minTurnDeg) result.add(b);
  }
  result.add(pts.last);
  return result;
}

/// Angle between two vectors in degrees, in [0, 180].
double _angleBetweenDeg(Offset a, Offset b) {
  if (a.distance == 0 || b.distance == 0) return 0;
  final dot = (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
  return math.acos(dot.clamp(-1.0, 1.0)) * 180 / math.pi;
}

Rect _boundsOf(List<Offset> points) {
  double minX = points.first.dx, maxX = points.first.dx;
  double minY = points.first.dy, maxY = points.first.dy;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

Offset _centroidOf(List<Offset> points) {
  double sumX = 0, sumY = 0;
  for (final p in points) {
    sumX += p.dx;
    sumY += p.dy;
  }
  return Offset(sumX / points.length, sumY / points.length);
}

/// Fits a (possibly rotated) rectangle to 4 corner points by estimating the
/// dominant edge orientation and re-projecting onto that rotated basis —
/// this is what lets a rectangle drawn at an angle snap to a *rotated*
/// perfect rectangle instead of forcing an axis-aligned one.
List<Offset> _fitRotatedRectangle(List<Offset> corners) {
  final centroid = _centroidOf(corners);

  // Order corners by angle around the centroid so edge vectors are
  // meaningful regardless of the order RDP happened to leave them in.
  final ordered = List<Offset>.from(corners)
    ..sort((a, b) {
      final angleA = math.atan2(a.dy - centroid.dy, a.dx - centroid.dx);
      final angleB = math.atan2(b.dy - centroid.dy, b.dx - centroid.dx);
      return angleA.compareTo(angleB);
    });

  final edge = ordered[1] - ordered[0];
  final theta = math.atan2(edge.dy, edge.dx);
  final u = Offset(math.cos(theta), math.sin(theta));
  final v = Offset(-math.sin(theta), math.cos(theta));

  double minU = double.infinity, maxU = -double.infinity;
  double minV = double.infinity, maxV = -double.infinity;
  for (final p in ordered) {
    final rel = p - centroid;
    final projU = rel.dx * u.dx + rel.dy * u.dy;
    final projV = rel.dx * v.dx + rel.dy * v.dy;
    if (projU < minU) minU = projU;
    if (projU > maxU) maxU = projU;
    if (projV < minV) minV = projV;
    if (projV > maxV) maxV = projV;
  }

  Offset corner(double du, double dv) => centroid + u * du + v * dv;

  final p0 = corner(minU, minV);
  final p1 = corner(maxU, minV);
  final p2 = corner(maxU, maxV);
  final p3 = corner(minU, maxV);
  return [p0, p1, p2, p3, p0]; // closed loop, matches existing convention
}

List<Offset> _generateOvalFromBounds(Rect bounds) {
  final center = bounds.center;
  final rx = bounds.width / 2;
  final ry = bounds.height / 2;
  return [
    for (int i = 0; i <= 60; i++)
      Offset(
        center.dx + rx * math.cos((i / 60) * math.pi * 2),
        center.dy + ry * math.sin((i / 60) * math.pi * 2),
      ),
  ];
}
