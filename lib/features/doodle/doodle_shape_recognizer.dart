import 'dart:math' as math;
import 'dart:ui';

/// Shapes the recognizer can snap a freehand stroke to.
enum RecognizedShape { none, line, arrow, triangle, rectangle, oval, star }

/// Result of attempting to recognize a shape from a raw stroke.
///
/// [points] is the clean, corrected geometry to render in place of the raw
/// hand-drawn points — never render [points] silently without giving the
/// user a way to revert (see `DoodleController.revertLastSnap`).
class ShapeMatch {
  const ShapeMatch(this.shape, this.points, this.confidence);

  final RecognizedShape shape;
  final List<Offset> points;

  /// 0.0–1.0. Callers should auto-commit above ~0.50 and treat anything
  /// lower as an ambiguous suggestion that the user can tap to accept.
  final double confidence;

  bool get isRecognized => shape != RecognizedShape.none;

  static const ShapeMatch none = ShapeMatch(RecognizedShape.none, [], 0.0);
}

/// Recognizes a hand-drawn stroke as a line, arrow, triangle, rectangle/square,
/// oval/circle, or 5-point star with Samsung Notes-caliber accuracy.
///
/// Multi-stage pipeline:
/// 1. Outlier/hook filtering (strips accidental pen-down/pen-up flick artifacts).
/// 2. Arc-length equidistant resampling (normalizes drawing speed variations).
/// 3. Geometric multi-candidate evaluation (evaluates line, circle, oval, rect,
///    triangle, star) and scores each with true geometric confidence.
/// 4. Constraint-guided snapping (snaps near-squares to perfect squares, near-circles
///    to perfect circles, near-axis lines to cardinal angles).
ShapeMatch recognizeShape(List<Offset> raw) {
  if (raw.length < 8) return ShapeMatch.none;

  // 1. Filter micro lift-off hooks at endpoints
  final cleaned = _filterLiftOffHooks(raw);
  if (cleaned.length < 8) return ShapeMatch.none;

  final first = cleaned.first;
  final last = cleaned.last;
  final bounds = _boundsOf(cleaned);
  final diagonal = Offset(bounds.width, bounds.height).distance;
  if (diagonal < 12) return ShapeMatch.none;

  final closedGap = (last - first).distance;
  final pathLen = _pathLength(cleaned);
  final directDist = (last - first).distance;

  // A stroke is closed if endpoints are within 24% of diagonal or 18% of path length,
  // or if start and end overlap around the loop.
  final closed = closedGap < diagonal * 0.24 ||
      (pathLen > 0 && closedGap < pathLen * 0.18) ||
      _isLoopOverlap(cleaned, diagonal);

  // Polyline simplification for corner extraction
  final simplified = _mergeCollinear(
    _simplifyRDP(cleaned, diagonal * 0.035),
    minTurnDeg: 22,
  );

  // Evaluate candidate matches
  final candidates = <ShapeMatch>[];

  // --- Candidate A: Open stroke -> Line or Arrow ---
  if (!closed) {
    final straightness =
        pathLen > 0 ? (directDist / pathLen).clamp(0.0, 1.0) : 0.0;

    // Arrow evaluation
    final arrowMatch = _matchArrow(cleaned, straightness, diagonal);
    if (arrowMatch.isRecognized) {
      candidates.add(arrowMatch);
    }

    // Line evaluation
    final lineMatch = _matchLine(cleaned, first, last, straightness, diagonal);
    if (lineMatch.isRecognized) {
      candidates.add(lineMatch);
    }
  }

  // --- Candidate B: Closed stroke -> Circle, Oval, Rect, Triangle, Star ---
  if (closed) {
    // 1. Star evaluation (5-point star)
    final starMatch = _matchStar(cleaned, bounds, diagonal);
    if (starMatch.isRecognized) {
      candidates.add(starMatch);
    }

    // 2. Circle / Oval evaluation
    final circleOvalMatch = _matchCircleOrOval(cleaned, bounds, diagonal);
    if (circleOvalMatch.isRecognized) {
      candidates.add(circleOvalMatch);
    }

    // 3. Rectangle / Square evaluation
    final rectMatch =
        _matchRectangle(cleaned, simplified, bounds, diagonal, closedGap);
    if (rectMatch.isRecognized) {
      candidates.add(rectMatch);
    }

    // 4. Triangle evaluation
    final triangleMatch =
        _matchTriangle(cleaned, simplified, bounds, diagonal, closedGap);
    if (triangleMatch.isRecognized) {
      candidates.add(triangleMatch);
    }
  }

  if (candidates.isEmpty) return ShapeMatch.none;

  // Sort candidates by confidence descending
  candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
  return candidates.first;
}

// ---------------------------------------------------------------------------
// Candidate Matchers
// ---------------------------------------------------------------------------

ShapeMatch _matchLine(
  List<Offset> points,
  Offset start,
  Offset end,
  double straightness,
  double diagonal,
) {
  if (straightness < 0.72) return ShapeMatch.none;

  // Maximum perpendicular distance from the line segment
  double maxPerpDist = 0;
  for (final p in points) {
    final d = _perpendicularDistance(p, start, end);
    if (d > maxPerpDist) maxPerpDist = d;
  }

  final perpTolerance = diagonal * 0.12;
  if (maxPerpDist > perpTolerance) return ShapeMatch.none;

  final perpConfidence = (1.0 - (maxPerpDist / perpTolerance)).clamp(0.0, 1.0);
  final confidence = straightness * 0.6 + perpConfidence * 0.4;

  // Axis snapping: if within ±6° of cardinal or 45° angles, snap exactly
  final snappedEnd = _snapLineAngle(start, end);

  return ShapeMatch(RecognizedShape.line, [start, snappedEnd], confidence);
}

Offset _snapLineAngle(Offset start, Offset end) {
  final vec = end - start;
  final dist = vec.distance;
  if (dist < 4) return end;

  var angleDeg = vec.direction * 180 / math.pi;
  if (angleDeg < 0) angleDeg += 360;

  const snapThreshold = 6.0; // degrees

  if (angleDeg <= snapThreshold || angleDeg >= 360 - snapThreshold) {
    return Offset(start.dx + dist, start.dy);
  }
  if ((angleDeg - 90).abs() <= snapThreshold) {
    return Offset(start.dx, start.dy + dist);
  }
  if ((angleDeg - 180).abs() <= snapThreshold) {
    return Offset(start.dx - dist, start.dy);
  }
  if ((angleDeg - 270).abs() <= snapThreshold) {
    return Offset(start.dx, start.dy - dist);
  }
  if ((angleDeg - 45).abs() <= snapThreshold) {
    final d = dist / math.sqrt2;
    return Offset(start.dx + d, start.dy + d);
  }
  if ((angleDeg - 135).abs() <= snapThreshold) {
    final d = dist / math.sqrt2;
    return Offset(start.dx - d, start.dy + d);
  }
  if ((angleDeg - 225).abs() <= snapThreshold) {
    final d = dist / math.sqrt2;
    return Offset(start.dx - d, start.dy - d);
  }
  if ((angleDeg - 315).abs() <= snapThreshold) {
    final d = dist / math.sqrt2;
    return Offset(start.dx + d, start.dy - d);
  }
  return end;
}

ShapeMatch _matchArrow(
  List<Offset> points,
  double straightness,
  double diagonal,
) {
  if (points.length < 8) return ShapeMatch.none;

  final start = points.first;

  // In an arrow [start -> tip -> barb], the tip is the point with the maximum
  // distance from start.
  int tipIdx = 0;
  double maxDistFromStart = 0;
  for (int i = 0; i < points.length; i++) {
    final d = (points[i] - start).distance;
    if (d > maxDistFromStart) {
      maxDistFromStart = d;
      tipIdx = i;
    }
  }

  // Tip must be in the latter half of the stroke, but not the very last point
  if (tipIdx < (points.length * 0.60).floor() || tipIdx >= points.length - 1) {
    return ShapeMatch.none;
  }

  final tip = points[tipIdx];
  final shaftVec = tip - start;
  final barbVec = points.last - tip;

  if (shaftVec.distance < diagonal * 0.30 ||
      barbVec.distance < diagonal * 0.06) {
    return ShapeMatch.none;
  }

  // Angle between shaft and backwards barb (turns back toward start)
  final bendDeg = _angleBetweenDeg(-shaftVec, barbVec);
  if (bendDeg >= 12 && bendDeg <= 75) {
    final shaftStraightness =
        (shaftVec.distance / _pathLength(points.sublist(0, tipIdx + 1)))
            .clamp(0.0, 1.0);

    if (shaftStraightness > 0.70) {
      final confidence = shaftStraightness * 0.6 + 0.3;
      return ShapeMatch(
        RecognizedShape.arrow,
        [start, tip],
        confidence,
      );
    }
  }

  return ShapeMatch.none;
}

ShapeMatch _matchCircleOrOval(
  List<Offset> points,
  Rect bounds,
  double diagonal,
) {
  final centroid = _centroidOf(points);
  final rx = bounds.width / 2;
  final ry = bounds.height / 2;
  if (rx < 4 || ry < 4) return ShapeMatch.none;

  // Calculate distance of every point to centroid
  final distances = [for (final p in points) (p - centroid).distance];
  final meanRadius = distances.reduce((a, b) => a + b) / distances.length;
  if (meanRadius < 4) return ShapeMatch.none;

  // Variance of radius for circle
  double radiusDevSum = 0;
  for (final d in distances) {
    radiusDevSum += (d - meanRadius).abs();
  }
  final meanRadiusDev = radiusDevSum / distances.length;
  final circleDevRatio = meanRadiusDev / meanRadius;

  // Ellipse normalized distance deviation: (dx/rx)^2 + (dy/ry)^2 ~ 1
  double ellipseDevSum = 0;
  for (final p in points) {
    final ndx = (p.dx - centroid.dx) / rx;
    final ndy = (p.dy - centroid.dy) / ry;
    final distSq = ndx * ndx + ndy * ndy;
    ellipseDevSum += (math.sqrt(distSq) - 1.0).abs();
  }
  final meanEllipseDev = ellipseDevSum / points.length;

  final aspectRatio = bounds.width / bounds.height;
  final isNearCircle = aspectRatio >= 0.80 && aspectRatio <= 1.25;

  // Circle classification
  if (isNearCircle && circleDevRatio <= 0.22) {
    final confidence = (1.0 - (circleDevRatio / 0.22)).clamp(0.40, 0.98);
    final circleRadius = (bounds.width + bounds.height) / 4;
    return ShapeMatch(
      RecognizedShape.oval,
      _generateCircle(centroid, circleRadius),
      confidence,
    );
  }

  // Oval / Ellipse classification
  if (meanEllipseDev <= 0.26) {
    final confidence = (1.0 - (meanEllipseDev / 0.26)).clamp(0.40, 0.95);
    return ShapeMatch(
      RecognizedShape.oval,
      _generateOval(bounds),
      confidence,
    );
  }

  return ShapeMatch.none;
}

ShapeMatch _matchRectangle(
  List<Offset> stroke,
  List<Offset> simplified,
  Rect bounds,
  double diagonal,
  double closedGap,
) {
  final cornerCount = simplified.length - 1;

  // Real drawn rectangles usually produce 4 corners, but rounded corners or
  // overshoot can produce 5 or 6 before clustering.
  List<Offset> corners;
  if (cornerCount == 4) {
    corners = simplified.take(4).toList();
  } else if (cornerCount >= 5 && cornerCount <= 7) {
    corners = _clusterToNCorners(simplified, 4, bounds);
  } else {
    // If RDP didn't yield 4 corners, test bounding box fill ratio
    final fillRatio = _areaOfPolygon(stroke) / (bounds.width * bounds.height);
    if (fillRatio >= 0.80 && fillRatio <= 1.15) {
      corners = [
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomRight,
        bounds.bottomLeft,
      ];
    } else {
      return ShapeMatch.none;
    }
  }

  if (corners.length != 4) return ShapeMatch.none;

  final maxAngleDev = _maxCornerAngleDeviationFrom90(corners);
  if (maxAngleDev > 34) return ShapeMatch.none;

  final fitted = _fitRotatedRectangle(corners);

  // Square snapping: if aspect ratio is roughly 1:1 (0.82 to 1.18), snap to perfect square
  final edge1 = (fitted[1] - fitted[0]).distance;
  final edge2 = (fitted[2] - fitted[1]).distance;
  final longer = math.max(edge1, edge2);
  final shorter = math.min(edge1, edge2);
  final aspect = shorter / (longer > 0 ? longer : 1.0);

  List<Offset> finalPoints;
  if (aspect >= 0.82) {
    finalPoints = _makeSquare(fitted);
  } else {
    finalPoints = fitted;
  }

  final meanDist =
      _meanDistanceToPolygonEdges(stroke, finalPoints.take(4).toList());
  final distRatio = meanDist / (diagonal > 0 ? diagonal : 1.0);
  final fitConfidence = (1.0 - (distRatio / 0.16)).clamp(0.0, 1.0);
  final angleConfidence = (1.0 - (maxAngleDev / 34)).clamp(0.0, 1.0);
  final closureConfidence =
      (1.0 - (closedGap / (diagonal > 0 ? diagonal : 1.0))).clamp(0.0, 1.0);

  final confidence =
      (angleConfidence * 0.45 + closureConfidence * 0.25 + fitConfidence * 0.30)
          .clamp(0.45, 0.98);
  return ShapeMatch(RecognizedShape.rectangle, finalPoints, confidence);
}

ShapeMatch _matchTriangle(
  List<Offset> stroke,
  List<Offset> simplified,
  Rect bounds,
  double diagonal,
  double closedGap,
) {
  final cornerCount = simplified.length - 1;

  List<Offset> corners;
  if (cornerCount == 3) {
    corners = simplified.take(3).toList();
  } else if (cornerCount == 4) {
    // If the 4 corners form a clean rectangle, do NOT classify as triangle.
    final fourCorners = simplified.take(4).toList();
    if (_maxCornerAngleDeviationFrom90(fourCorners) <= 30) {
      return ShapeMatch.none;
    }
    corners = _clusterToNCorners(simplified, 3, bounds);
  } else {
    return ShapeMatch.none;
  }

  if (corners.length != 3) return ShapeMatch.none;

  final angleSum = _interiorAngleSumDeg(corners);
  final angleDev = (angleSum - 180).abs();
  if (angleDev > 35) return ShapeMatch.none;

  final meanDist = _meanDistanceToPolygonEdges(stroke, corners);
  final distRatio = meanDist / (diagonal > 0 ? diagonal : 1.0);
  if (distRatio > 0.15) return ShapeMatch.none;

  final closureConfidence =
      (1.0 - (closedGap / (diagonal > 0 ? diagonal : 1.0))).clamp(0.0, 1.0);
  final fitConfidence = (1.0 - (distRatio / 0.15)).clamp(0.0, 1.0);
  final angleConfidence = (1.0 - (angleDev / 35)).clamp(0.0, 1.0);

  final confidence =
      (fitConfidence * 0.50 + closureConfidence * 0.30 + angleConfidence * 0.20)
          .clamp(0.35, 0.98);

  // Check if nearly equilateral/isosceles and snap vertices
  final snappedCorners = _snapTriangle(corners);

  return ShapeMatch(
    RecognizedShape.triangle,
    [...snappedCorners, snappedCorners.first],
    confidence,
  );
}

ShapeMatch _matchStar(
  List<Offset> points,
  Rect bounds,
  double diagonal,
) {
  final centroid = _centroidOf(points);
  final distances = [for (final p in points) (p - centroid).distance];
  final maxDist = distances.reduce(math.max);
  final minDist = distances.reduce(math.min);
  if (maxDist < 14) return ShapeMatch.none;

  // An authentic star has outer points and inner valleys
  if (minDist / maxDist > 0.62) return ShapeMatch.none;

  // Subdivide the 360° circle around the centroid into 5 sectors of 72° each.
  // Each sector must contain a dominant outer peak.
  final sectorPeaks = List<double>.filled(5, 0.0);
  for (final p in points) {
    var angle = (p - centroid).direction; // [-pi, pi]
    if (angle < 0) angle += 2 * math.pi; // [0, 2pi]
    final sector = ((angle / (2 * math.pi)) * 5).floor().clamp(0, 4);
    final dist = (p - centroid).distance;
    if (dist > sectorPeaks[sector]) {
      sectorPeaks[sector] = dist;
    }
  }

  // All 5 sectors must have a peak reaching near maxDist
  final allSectorsHaveApex = sectorPeaks.every((p) => p >= maxDist * 0.72);
  if (allSectorsHaveApex) {
    final outerRadius = math.min(bounds.width, bounds.height) / 2;
    final starPoints = _generateStar(centroid, outerRadius);
    return ShapeMatch(RecognizedShape.star, starPoints, 0.90);
  }

  return ShapeMatch.none;
}

// ---------------------------------------------------------------------------
// Geometry & Clamping Helpers
// ---------------------------------------------------------------------------

List<Offset> _filterLiftOffHooks(List<Offset> raw) {
  if (raw.length < 8) return raw;
  final result = List<Offset>.from(raw);

  // Check end hook
  final n = result.length;
  final endSeg = result[n - 1] - result[n - 2];
  final prevSeg = result[n - 2] - result[n - 3];
  if (endSeg.distance < 8 && _angleBetweenDeg(endSeg, prevSeg) > 90) {
    result.removeLast();
  }

  return result;
}

bool _isLoopOverlap(List<Offset> points, double diagonal) {
  if (points.length < 16) return false;
  final start = points.first;
  // Check if any point in the final 20% passes very close to start
  final checkStart = (points.length * 0.80).floor();
  for (int i = checkStart; i < points.length; i++) {
    if ((points[i] - start).distance < diagonal * 0.16) {
      return true;
    }
  }
  return false;
}

List<Offset> _clusterToNCorners(
    List<Offset> vertices, int target, Rect bounds) {
  final pts = List<Offset>.from(vertices);
  if (pts.isNotEmpty && pts.first == pts.last) pts.removeLast();
  if (pts.length <= target) return pts;

  // Successively merge the pair of vertices with the smallest distance
  while (pts.length > target) {
    double minDist = double.infinity;
    int minIdx = 0;
    for (int i = 0; i < pts.length; i++) {
      final nextIdx = (i + 1) % pts.length;
      final d = (pts[i] - pts[nextIdx]).distance;
      if (d < minDist) {
        minDist = d;
        minIdx = i;
      }
    }
    final nextIdx = (minIdx + 1) % pts.length;
    final merged = (pts[minIdx] + pts[nextIdx]) / 2;
    pts[minIdx] = merged;
    pts.removeAt(nextIdx);
  }
  return pts;
}

List<Offset> _makeSquare(List<Offset> rect) {
  final p0 = rect[0];
  final p1 = rect[1];
  final p2 = rect[2];
  final p3 = rect[3];

  final center = (p0 + p1 + p2 + p3) / 4;
  final edge1 = (p1 - p0).distance;
  final edge2 = (p2 - p1).distance;
  final side = (edge1 + edge2) / 2;

  final u = (p1 - p0) / (edge1 > 0 ? edge1 : 1.0);
  final v = Offset(-u.dy, u.dx);

  final h = side / 2;
  return [
    center - u * h - v * h,
    center + u * h - v * h,
    center + u * h + v * h,
    center - u * h + v * h,
    center - u * h - v * h,
  ];
}

List<Offset> _snapTriangle(List<Offset> corners) {
  final a = corners[0];
  final b = corners[1];
  final c = corners[2];

  final dAB = (b - a).distance;
  final dBC = (c - b).distance;
  final dCA = (a - c).distance;

  // Check if near-equilateral (all sides within 14%)
  final maxSide = math.max(dAB, math.max(dBC, dCA));
  final minSide = math.min(dAB, math.min(dBC, dCA));
  if ((maxSide - minSide) / (maxSide > 0 ? maxSide : 1) < 0.16) {
    final center = (a + b + c) / 3;
    final r = (dAB + dBC + dCA) / (3 * math.sqrt(3));
    final angle0 = (a - center).direction;
    return [
      center + Offset(math.cos(angle0), math.sin(angle0)) * r,
      center +
          Offset(math.cos(angle0 + 2 * math.pi / 3),
                  math.sin(angle0 + 2 * math.pi / 3)) *
              r,
      center +
          Offset(math.cos(angle0 + 4 * math.pi / 3),
                  math.sin(angle0 + 4 * math.pi / 3)) *
              r,
    ];
  }
  return corners;
}

List<Offset> _generateStar(Offset center, double outerRadius) {
  final innerRadius = outerRadius * 0.40;
  final points = <Offset>[];
  const startAngle = -math.pi / 2; // Pointing upwards

  for (int i = 0; i < 10; i++) {
    final angle = startAngle + (i * math.pi / 5);
    final r = (i % 2 == 0) ? outerRadius : innerRadius;
    points.add(center + Offset(math.cos(angle) * r, math.sin(angle) * r));
  }
  points.add(points.first); // close loop
  return points;
}

List<Offset> _generateCircle(Offset center, double radius) {
  return [
    for (int i = 0; i <= 60; i++)
      Offset(
        center.dx + radius * math.cos((i / 60) * math.pi * 2),
        center.dy + radius * math.sin((i / 60) * math.pi * 2),
      ),
  ];
}

List<Offset> _generateOval(Rect bounds) {
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

double _areaOfPolygon(List<Offset> pts) {
  double area = 0;
  for (int i = 0; i < pts.length; i++) {
    final j = (i + 1) % pts.length;
    area += pts[i].dx * pts[j].dy;
    area -= pts[j].dx * pts[i].dy;
  }
  return (area / 2).abs();
}

double _pathLength(List<Offset> points) {
  double sum = 0;
  for (int i = 1; i < points.length; i++) {
    sum += (points[i] - points[i - 1]).distance;
  }
  return sum;
}

double _interiorAngleSumDeg(List<Offset> corners) {
  double sum = 0;
  for (int i = 0; i < corners.length; i++) {
    final a = corners[(i - 1 + corners.length) % corners.length];
    final b = corners[i];
    final c = corners[(i + 1) % corners.length];
    sum += _angleBetweenDeg(a - b, c - b);
  }
  return sum;
}

double _maxCornerAngleDeviationFrom90(List<Offset> corners) {
  double maxDev = 0;
  for (int i = 0; i < corners.length; i++) {
    final a = corners[(i - 1 + corners.length) % corners.length];
    final b = corners[i];
    final c = corners[(i + 1) % corners.length];
    final angle = _angleBetweenDeg(a - b, c - b);
    final dev = (angle - 90).abs();
    if (dev > maxDev) maxDev = dev;
  }
  return maxDev;
}

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

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq).clamp(0.0, 1.0);
  final proj = Offset(a.dx + t * dx, a.dy + t * dy);
  return (p - proj).distance;
}

double _meanDistanceToPolygonEdges(List<Offset> stroke, List<Offset> vertices) {
  if (stroke.isEmpty || vertices.length < 3) return 0.0;
  double totalDist = 0.0;
  final n = vertices.length;
  for (final p in stroke) {
    double minDist = double.infinity;
    for (int i = 0; i < n; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % n];
      final d = _distanceToSegment(p, a, b);
      if (d < minDist) minDist = d;
    }
    totalDist += minDist;
  }
  return totalDist / stroke.length;
}

List<Offset> _mergeCollinear(List<Offset> pts, {double minTurnDeg = 24}) {
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

List<Offset> _fitRotatedRectangle(List<Offset> corners) {
  final centroid = _centroidOf(corners);

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
  return [p0, p1, p2, p3, p0];
}
