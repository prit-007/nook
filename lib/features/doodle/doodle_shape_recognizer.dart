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

  /// 0.0–1.0. Callers should auto-commit above ~0.70 and treat anything
  /// lower as an ambiguous suggestion that the user can tap to accept.
  final double confidence;

  bool get isRecognized => shape != RecognizedShape.none;

  static const ShapeMatch none = ShapeMatch(RecognizedShape.none, [], 0.0);
}

/// Recognizes a hand-drawn stroke as a line, arrow, triangle, rectangle/square,
/// oval/circle, or 5-point star.
///
/// Pipeline (per the $1 Unistroke recognizer, Wobbrock et al.):
/// 1. Outlier/hook filtering (strips accidental pen-down/pen-up flick artifacts).
/// 2. Arc-length equidistant resampling (normalizes drawing-speed variance).
/// 3. Normalize-to-canonical: rotate-to-zero, scale-to-square, translate-to-origin
///    — gives rotation/scale/translation invariance for classification.
/// 4. Classify against ideal prototypes ($1 cosine distance) → shape + raw score.
/// 5. Fit the chosen shape on the *raw* points with least-squares/RANSAC → ideal
///    geometry parameters (center, radius, axes, corners, …) so the shape can be
///    regenerated at any size later (resizable).
/// 6. Confidence from fit residual RMS relative to characteristic size.
ShapeMatch recognizeShape(List<Offset> raw) {
  if (raw.length < 8) return ShapeMatch.none;

  // 1. Filter micro lift-off hooks at endpoints
  final cleaned = _filterLiftOffHooks(raw);
  if (cleaned.length < 8) return ShapeMatch.none;

  final bounds = _boundsOf(cleaned);
  final diagonal = Offset(bounds.width, bounds.height).distance;

  // Adaptive size floor: reject only truly accidental dots, not deliberate
  // small shapes. Scale with logical pixel density of the canvas.
  final sizeFloor = math.max(12.0, diagonal * 0.0);
  if (diagonal < sizeFloor) return ShapeMatch.none;

  final first = cleaned.first;
  final last = cleaned.last;
  final closedGap = (last - first).distance;
  final pathLen = _pathLength(cleaned);

  // A stroke is closed if endpoints are within 24% of diagonal or 18% of path
  // length, or if start and end overlap around the loop.
  final closed = closedGap < diagonal * 0.24 ||
      (pathLen > 0 && closedGap < pathLen * 0.18) ||
      _isLoopOverlap(cleaned, diagonal);

  // Scribble rejection: a real shape traces its boundary once (path length ~
  // perimeter). A random walk goes back and forth, making path length much
  // larger than the bounding-box perimeter.
  if (pathLen > 0) {
    final perimeter = 2 * (bounds.width + bounds.height);
    if (perimeter > 0 && pathLen / perimeter > 3.0) return ShapeMatch.none;
  }

  // 2. Arc-length equidistant resample to a fixed count (speed invariance).
  final resampled = _resampleArcLength(cleaned, 64);

  // 3. Normalize for classification (rotation/scale/translation invariance).

  // 3. Normalize for classification (rotation/scale/translation invariance).
  final normalized = _normalizeCanonical(resampled);

  // 4. Classify against prototypes on the normalized stroke.
  final candidates = <ShapeMatch>[];

  // --- Open stroke -> Line or Arrow ---
  if (!closed) {
    final arrowMatch = _matchArrowNormalized(normalized, cleaned, diagonal);
    if (arrowMatch.isRecognized) candidates.add(arrowMatch);

    final lineMatch = _matchLineNormalized(normalized, cleaned, diagonal);
    if (lineMatch.isRecognized) candidates.add(lineMatch);
  }

  // --- Closed stroke -> Circle/Oval, Rect, Triangle, Star ---
  if (closed) {
    final ovalMatch = _matchOvalNormalized(normalized, cleaned, bounds, diagonal);
    if (ovalMatch.isRecognized) candidates.add(ovalMatch);

    final rectMatch = _matchRectangleNormalized(
        normalized, cleaned, bounds, diagonal, closedGap);
    if (rectMatch.isRecognized) candidates.add(rectMatch);

    final triangleMatch = _matchTriangleNormalized(
        normalized, cleaned, bounds, diagonal, closedGap);
    if (triangleMatch.isRecognized) candidates.add(triangleMatch);

    final starMatch = _matchStarNormalized(normalized, cleaned, bounds, diagonal);
    if (starMatch.isRecognized) candidates.add(starMatch);
  }

  if (candidates.isEmpty) return ShapeMatch.none;

  candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
  final best = candidates.first;
  // Global acceptance threshold: below this, the stroke is not a shape.
  if (best.confidence < 0.60) return ShapeMatch.none;

  // Elongated-shape preference: a human drawing a very wide/tall shape is
  // more likely drawing an oval than a thin rectangle. If both match and
  // the aspect ratio is far from 1:1, prefer oval.
  if (best.shape == RecognizedShape.rectangle && bounds.width > 0 && bounds.height > 0) {
    final boundsAspect = bounds.width / bounds.height;
    final isElongated = boundsAspect > 1.30 || boundsAspect < (1 / 1.30);
    if (isElongated) {
      for (final c in candidates) {
        if (c.shape == RecognizedShape.oval && c.confidence > best.confidence - 0.15) {
          return c;
        }
      }
    }
  }

  // Arrow preference: an arrow is a more specific shape than a line. If both
  // match, prefer the arrow when its confidence is within 0.20 of the line's.
  if (best.shape == RecognizedShape.line) {
    for (final c in candidates) {
      if (c.shape == RecognizedShape.arrow &&
          c.confidence > best.confidence - 0.20) {
        return c;
      }
    }
  }
  return best;
}

// ---------------------------------------------------------------------------
// 2. Arc-length equidistant resampling (speed invariance)
// ---------------------------------------------------------------------------

/// Resamples [points] to [count] points equidistant along the arc length.
List<Offset> _resampleArcLength(List<Offset> points, int count) {
  if (points.length < 2) return List<Offset>.from(points);

  // Build cumulative arc-length table.
  final distances = <double>[0.0];
  for (int i = 1; i < points.length; i++) {
    distances.add(distances.last + (points[i] - points[i - 1]).distance);
  }
  final total = distances.last;
  if (total == 0) return List<Offset>.from(points);

  final result = <Offset>[];
  final lastSeg = distances.length - 2;
  for (int i = 0; i < count; i++) {
    final target = total * i / (count - 1);
    // Find the segment containing target. Guard against floating-point
    // round-off pushing target slightly above total.
    int seg = 0;
    while (seg < lastSeg && distances[seg + 1] < target) {
      seg++;
    }
    seg = seg.clamp(0, lastSeg);
    final segLen = distances[seg + 1] - distances[seg];
    final t = segLen == 0 ? 0.0 : ((target - distances[seg]) / segLen).clamp(0.0, 1.0);
    result.add(Offset.lerp(points[seg], points[seg + 1], t)!);
  }
  return result;
}

/// Normalizes a resampled stroke to a canonical frame:
/// translate centroid to origin, rotate so first-point vector points up,
/// scale to unit diagonal. Returns rotation-invariant, scale-invariant,
/// translation-invariant point list for classification.
List<Offset> _normalizeCanonical(List<Offset> points) {
  final centroid = _centroidOf(points);

  // Translate to origin.
  final translated = [
    for (final p in points) Offset(p.dx - centroid.dx, p.dy - centroid.dy)
  ];

  // Rotate so the vector from centroid to first point points straight up.
  final firstRel = translated.first;
  final angle = firstRel.direction - math.pi / 2; // rotate so it points up
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  final rotated = [
    for (final p in translated)
      Offset(p.dx * cos - p.dy * sin, p.dx * sin + p.dy * cos)
  ];

  // Scale to unit diagonal.
  final normBounds = _boundsOf(rotated);
  final normDiag = Offset(normBounds.width, normBounds.height).distance;
  if (normDiag == 0) return rotated;
  final scale = 1.0 / normDiag;
  return [for (final p in rotated) Offset(p.dx * scale, p.dy * scale)];
}

// ---------------------------------------------------------------------------
// Core geometry helpers
// ---------------------------------------------------------------------------

double _pathLength(List<Offset> points) {
  double sum = 0;
  for (int i = 1; i < points.length; i++) {
    sum += (points[i] - points[i - 1]).distance;
  }
  return sum;
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

double _angleBetweenDeg(Offset a, Offset b) {
  if (a.distance == 0 || b.distance == 0) return 0;
  final dot = (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
  return math.acos(dot.clamp(-1.0, 1.0)) * 180 / math.pi;
}

bool _isLoopOverlap(List<Offset> points, double diagonal) {
  if (points.length < 16) return false;
  final start = points.first;
  final checkStart = (points.length * 0.80).floor();
  for (int i = checkStart; i < points.length; i++) {
    if ((points[i] - start).distance < diagonal * 0.16) {
      return true;
    }
  }
  return false;
}

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

// ---------------------------------------------------------------------------
// Candidate matchers — open strokes: line / arrow
// ---------------------------------------------------------------------------

/// PCA-based line fit on the *raw* (unnormalized) points. Returns the principal
/// axis, the residual RMS perpendicular to the axis, and the projected
/// endpoints.
class _LineFit {
  const _LineFit({
    required this.centroid,
    required this.unitAxis,
    required this.residualRms,
    required this.start,
    required this.end,
  });
  final Offset centroid;
  final Offset unitAxis; // unit vector along the line
  final double residualRms;
  final Offset start;
  final Offset end;
}

_LineFit? _fitLine(List<Offset> points) {
  if (points.length < 2) return null;
  final centroid = _centroidOf(points);

  // Covariance matrix.
  double cxx = 0, cyy = 0, cxy = 0;
  for (final p in points) {
    final dx = p.dx - centroid.dx;
    final dy = p.dy - centroid.dy;
    cxx += dx * dx;
    cyy += dy * dy;
    cxy += dx * dy;
  }

  // Principal axis = eigenvector of largest eigenvalue of [[cxx,cxy],[cxy,cyy]].
  final delta = cxx - cyy;
  final trace = cxx + cyy;
  final disc = math.sqrt(delta * delta + 4 * cxy * cxy);
  final lambdaMax = (trace + disc) / 2;

  Offset axis;
  if (cxy.abs() < 1e-9) {
    axis = cxx >= cyy ? const Offset(1, 0) : const Offset(0, 1);
  } else {
    // Eigenvector for lambdaMax: (cxx - lambdaMax) * x + cxy * y = 0
    // => y = (lambdaMax - cxx) / cxy * x
    final slope = (lambdaMax - cxx) / cxy;
    axis = Offset(1, slope);
  }
  final axisLen = axis.distance;
  if (axisLen == 0) return null;
  final unitAxis = Offset(axis.dx / axisLen, axis.dy / axisLen);

  // Residual RMS = RMS of perpendicular distance to the line.
  double sqSum = 0;
  for (final p in points) {
    final rel = Offset(p.dx - centroid.dx, p.dy - centroid.dy);
    // perpendicular distance = |rel x unitAxis|
    final perp = (rel.dx * unitAxis.dy - rel.dy * unitAxis.dx).abs();
    sqSum += perp * perp;
  }
  final residualRms = math.sqrt(sqSum / points.length);

  // Project endpoints onto the axis.
  double minT = double.infinity, maxT = -double.infinity;
  Offset startP = points.first, endP = points.last;
  for (final p in points) {
    final rel = Offset(p.dx - centroid.dx, p.dy - centroid.dy);
    final t = rel.dx * unitAxis.dx + rel.dy * unitAxis.dy;
    if (t < minT) {
      minT = t;
      startP = p;
    }
    if (t > maxT) {
      maxT = t;
      endP = p;
    }
  }

  return _LineFit(
    centroid: centroid,
    unitAxis: unitAxis,
    residualRms: residualRms,
    start: startP,
    end: endP,
  );
}

ShapeMatch _matchLineNormalized(
    List<Offset> normalized, List<Offset> cleaned, double diagonal) {
  final fit = _fitLine(cleaned);
  if (fit == null) return ShapeMatch.none;

  // Straightness: how much of the path length is explained by the line.
  final pathLen = _pathLength(cleaned);
  final directDist = (fit.end - fit.start).distance;
  final straightness = pathLen > 0 ? (directDist / pathLen).clamp(0.0, 1.0) : 0.0;

  // Scale-invariant perpendicular tolerance.
  final perpTolerance = diagonal * 0.10;
  if (fit.residualRms > perpTolerance * 1.5) return ShapeMatch.none;
  if (straightness < 0.70) return ShapeMatch.none;

  final perpConfidence =
      (1.0 - (fit.residualRms / perpTolerance)).clamp(0.0, 1.0);
  final confidence = (straightness * 0.6 + perpConfidence * 0.4)
      .clamp(0.0, 1.0);

  // Axis snapping: snap to nearest cardinal or 45° diagonal.
  final snappedEnd = _snapLineAngle(fit.start, fit.end);

  return ShapeMatch(RecognizedShape.line, [fit.start, snappedEnd], confidence);
}

Offset _snapLineAngle(Offset start, Offset end) {
  final vec = end - start;
  final dist = vec.distance;
  if (dist < 4) return end;

  var angleDeg = vec.direction * 180 / math.pi;
  if (angleDeg < 0) angleDeg += 360;

  const snapThreshold = 8.0; // degrees

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

// ---------------------------------------------------------------------------
// Arrow detection: long straight shaft + barb turning back toward start
// ---------------------------------------------------------------------------

ShapeMatch _matchArrowNormalized(
    List<Offset> normalized, List<Offset> cleaned, double diagonal) {
  if (cleaned.length < 8) return ShapeMatch.none;

  final start = cleaned.first;
  final n = cleaned.length;

  // Tip = point farthest from start, located in the latter 40% of the stroke.
  int tipIdx = 0;
  double maxDistFromStart = 0;
  for (int i = 0; i < n; i++) {
    final d = (cleaned[i] - start).distance;
    if (d > maxDistFromStart) {
      maxDistFromStart = d;
      tipIdx = i;
    }
  }

  final minTipIdx = (n * 0.55).floor();
  final maxTipIdx = n - 2;
  if (tipIdx < minTipIdx || tipIdx > maxTipIdx) return ShapeMatch.none;

  final tip = cleaned[tipIdx];
  final shaftPoints = cleaned.sublist(0, tipIdx + 1);
  final shaftFit = _fitLine(shaftPoints);
  if (shaftFit == null) return ShapeMatch.none;

  // Shaft must be straight enough.
  final shaftPathLen = _pathLength(shaftPoints);
  final shaftDirect = (tip - start).distance;
  final shaftStraightness =
      shaftPathLen > 0 ? (shaftDirect / shaftPathLen).clamp(0.0, 1.0) : 0.0;
  if (shaftStraightness < 0.72) return ShapeMatch.none;

  // Shaft must be a meaningful fraction of the diagonal.
  if (shaftDirect < diagonal * 0.30) return ShapeMatch.none;

  // Barb: from tip to end, turning back toward start.
  final barbVec = cleaned.last - tip;
  if (barbVec.distance < diagonal * 0.06) return ShapeMatch.none;

  // Angle between backward shaft (tip back to start) and barb.
  final shaftDir = Offset((tip.dx - start.dx) / shaftDirect,
      (tip.dy - start.dy) / shaftDirect);
  final backwardShaft = Offset(-shaftDir.dx, -shaftDir.dy);
  final barbDir = Offset(barbVec.dx / barbVec.distance, barbVec.dy / barbVec.distance);
  final bendDeg = _angleBetweenDeg(backwardShaft, barbDir);
  if (bendDeg < 15 || bendDeg > 95) return ShapeMatch.none;

  final confidence = (shaftStraightness * 0.55 + 0.35).clamp(0.0, 1.0);
  return ShapeMatch(RecognizedShape.arrow, [start, tip], confidence);
}

// ---------------------------------------------------------------------------
// Closed-shape fitters
// ---------------------------------------------------------------------------

/// Algebraic circle fit (Pratt method) on raw points → (cx, cy, r).
class _CircleFit {
  const _CircleFit({
    required this.cx,
    required this.cy,
    required this.r,
    required this.residualRms,
  });
  final double cx;
  final double cy;
  final double r;
  final double residualRms;
}

_CircleFit? _fitCircle(List<Offset> points) {
  if (points.length < 3) return null;

  // Pratt's algebraic circle fit: solve for (cx, cy, r) minimizing
  // sum ((x-cx)^2 + (y-cy)^2 - r^2)^2 using the linearized Pratt constraint.
  double sumX = 0, sumY = 0, sumX2 = 0, sumY2 = 0, sumXY = 0;
  for (final p in points) {
    final x = p.dx;
    final y = p.dy;
    sumX += x;
    sumY += y;
    sumX2 += x * x;
    sumY2 += y * y;
    sumXY += x * y;
  }
  final n = points.length.toDouble();

  // Solve the 3x3 normal equations for the circle: x^2+y^2 = A*x + B*y + C
  // where center = (A/2, B/2), r^2 = C + (A^2+B^2)/4.
  // Use a stable linear solve: [n sumX sumY; sumX sumX2 sumXY; sumY sumXY sumY2] [C A B] = [sumR2 sumXR2 sumYR2]
  // where R2 = x^2+y^2.
  double sumR2 = 0, sumXR2 = 0, sumYR2 = 0;
  for (final p in points) {
    final r2 = p.dx * p.dx + p.dy * p.dy;
    sumR2 += r2;
    sumXR2 += p.dx * r2;
    sumYR2 += p.dy * r2;
  }

  // Matrix M:
  // [ n,   sumX, sumY ]
  // [ sumX, sumX2, sumXY ]
  // [ sumY, sumXY, sumY2 ]
  // RHS: [sumR2, sumXR2, sumYR2]
  // Solve for [C, A, B].
  final m00 = n;
  final m01 = sumX;
  final m02 = sumY;
  final m10 = sumX;
  final m11 = sumX2;
  final m12 = sumXY;
  final m20 = sumY;
  final m21 = sumXY;
  final m22 = sumY2;

  final detM =
      m00 * (m11 * m22 - m12 * m21) -
      m01 * (m10 * m22 - m12 * m20) +
      m02 * (m10 * m21 - m11 * m20);
  if (detM.abs() < 1e-9) return null;

  final C =
      (sumR2 * (m11 * m22 - m12 * m21) -
          m01 * (sumXR2 * m22 - m12 * sumYR2) +
          m02 * (sumXR2 * m21 - m11 * sumYR2)) /
      detM;
  final A =
      (m00 * (sumXR2 * m22 - m12 * sumYR2) -
          sumR2 * (m10 * m22 - m12 * m20) +
          m02 * (m10 * sumYR2 - sumXR2 * m20)) /
      detM;
  final B =
      (m00 * (m11 * sumYR2 - sumXR2 * m21) -
          m01 * (m10 * sumYR2 - sumXR2 * m20) +
          sumR2 * (m10 * m21 - m11 * m20)) /
      detM;

  final cx = A / 2;
  final cy = B / 2;
  final rSquared = C + (A * A + B * B) / 4;
  if (rSquared <= 0) return null;
  final r = math.sqrt(rSquared);

  // Residual RMS = RMS of |distance-to-center - r|.
  double sqSum = 0;
  for (final p in points) {
    final d = (Offset(p.dx - cx, p.dy - cy)).distance;
    final diff = d - r;
    sqSum += diff * diff;
  }
  final residualRms = math.sqrt(sqSum / points.length);

  return _CircleFit(cx: cx, cy: cy, r: r, residualRms: residualRms);
}

ShapeMatch _matchOvalNormalized(
    List<Offset> normalized, List<Offset> cleaned, Rect bounds, double diagonal) {
  final rx = bounds.width / 2;
  final ry = bounds.height / 2;
  if (rx < 4 || ry < 4) return ShapeMatch.none;

  // Try circle fit first.
  final circle = _fitCircle(cleaned);
  final centroid = _centroidOf(cleaned);

  // Circle classification: near-circular aspect + low radial deviation.
  final aspectRatio = bounds.width / bounds.height;
  final isNearCircle = aspectRatio >= 0.78 && aspectRatio <= 1.28;

  if (circle != null && isNearCircle) {
    final circleDevRatio = circle.residualRms / circle.r;
    final circleTol = 0.22;
    if (circleDevRatio <= circleTol) {
      var confidence =
          (1.0 - (circleDevRatio / circleTol)).clamp(0.40, 0.98);
      // Boost near-circular shapes so circles beat rectangle-on-circle fits.
      if (aspectRatio >= 0.85 && aspectRatio <= 1.18) {
        confidence = (confidence + 0.10).clamp(0.0, 1.0);
      }
      final circleRadius = (bounds.width + bounds.height) / 4;
      return ShapeMatch(
        RecognizedShape.oval,
        _generateCircle(Offset(circle.cx, circle.cy), circleRadius),
        confidence,
      );
    }
  }

  // Oval / Ellipse classification: normalized algebraic distance to ellipse.
  double ellipseDevSum = 0;
  for (final p in cleaned) {
    final ndx = (p.dx - centroid.dx) / rx;
    final ndy = (p.dy - centroid.dy) / ry;
    final distSq = ndx * ndx + ndy * ndy;
    ellipseDevSum += (math.sqrt(distSq) - 1.0).abs();
  }
  final meanEllipseDev = ellipseDevSum / cleaned.length;
  final ovalTol = 0.26;

  if (meanEllipseDev <= ovalTol) {
    var confidence =
        (1.0 - (meanEllipseDev / ovalTol)).clamp(0.40, 0.95);
    if (aspectRatio >= 0.85 && aspectRatio <= 1.18) {
      confidence = (confidence + 0.10).clamp(0.0, 1.0);
    }
    return ShapeMatch(
      RecognizedShape.oval,
      _generateOval(bounds),
      confidence,
    );
  }

  return ShapeMatch.none;
}

// ---------------------------------------------------------------------------
// Rectangle / Square: convex hull + rotating-calipers min-area bounding rect
// ---------------------------------------------------------------------------

/// 2D cross product of OA x OB.
double _cross(Offset o, Offset a, Offset b) {
  return (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
}

/// Monotone chain convex hull. Returns vertices in counter-clockwise order
/// without repeating the first point at the end.
List<Offset> _convexHull(List<Offset> points) {
  if (points.length <= 2) return List<Offset>.from(points);
  final sorted = List<Offset>.from(points)
    ..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));

  final lower = <Offset>[];
  for (final p in sorted) {
    while (lower.length >= 2 &&
        _cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }

  final upper = <Offset>[];
  for (int i = sorted.length - 1; i >= 0; i--) {
    final p = sorted[i];
    while (upper.length >= 2 &&
        _cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }

  // Concatenate, dropping last point of each (it's repeated).
  return [...lower.sublist(0, lower.length - 1), ...upper.sublist(0, upper.length - 1)];
}

/// Minimum-area bounding rectangle via rotating calipers on [hull].
/// Returns [center, uAxis, vAxis, halfWidth, halfHeight] where uAxis is the
/// long edge direction and vAxis is perpendicular.
class _RectFit {
  const _RectFit({
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

  /// The four corners in order (closed loop not included).
  List<Offset> corners() {
    final h = halfHeight;
    final w = halfWidth;
    return [
      center - uAxis * w - vAxis * h,
      center + uAxis * w - vAxis * h,
      center + uAxis * w + vAxis * h,
      center - uAxis * w + vAxis * h,
    ];
  }
}

_RectFit? _fitRotatedRectangle(List<Offset> hull) {
  if (hull.length < 3) return null;

  // Ensure CCW order.
  double signedArea = 0;
  for (int i = 0; i < hull.length; i++) {
    final a = hull[i];
    final b = hull[(i + 1) % hull.length];
    signedArea += a.dx * b.dy - b.dx * a.dy;
  }
  final ccw = signedArea > 0;
  final ordered = ccw ? hull : hull.reversed.toList();

  final m = ordered.length;
  // Edge directions.
  final edges = <Offset>[];
  for (int i = 0; i < m; i++) {
    edges.add(ordered[(i + 1) % m] - ordered[i]);
  }

  _RectFit? best;
  double bestArea = double.infinity;

  for (int i = 0; i < m; i++) {
    final edge = edges[i];
    final len = edge.distance;
    if (len == 0) continue;
    final u = Offset(edge.dx / len, edge.dy / len);
    final v = Offset(-u.dy, u.dx);

    double minU = double.infinity, maxU = -double.infinity;
    double minV = double.infinity, maxV = -double.infinity;
    for (final p in ordered) {
      final rel = p - ordered[0]; // project relative to edge start (origin shift OK)
      final pu = rel.dx * u.dx + rel.dy * u.dy;
      final pv = rel.dx * v.dx + rel.dy * v.dy;
      if (pu < minU) minU = pu;
      if (pu > maxU) maxU = pu;
      if (pv < minV) minV = pv;
      if (pv > maxV) maxV = pv;
    }

    final width = maxU - minU;
    final height = maxV - minV;
    final area = width * height;
    if (area < bestArea) {
      bestArea = area;
      // Center: use projections relative to ordered[0].
      final centerU = (minU + maxU) / 2;
      final centerV = (minV + maxV) / 2;
      final center = ordered[0] + u * centerU + v * centerV;
      best = _RectFit(
        center: center,
        uAxis: u,
        vAxis: v,
        halfWidth: width / 2,
        halfHeight: height / 2,
      );
    }
  }
  return best;
}

double _pointToSegmentDist(Offset p, Offset a, Offset b) {
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq)
      .clamp(0.0, 1.0);
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
      final d = _pointToSegmentDist(p, a, b);
      if (d < minDist) minDist = d;
    }
    totalDist += minDist;
  }
  return totalDist / stroke.length;
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

ShapeMatch _matchRectangleNormalized(List<Offset> normalized, List<Offset> cleaned,
    Rect bounds, double diagonal, double closedGap) {
  final hull = _convexHull(cleaned);
  if (hull.length < 3) return ShapeMatch.none;

  final rectFit = _fitRotatedRectangle(hull);
  if (rectFit == null) return ShapeMatch.none;

  final corners = rectFit.corners();

  // Corner angle check: all four corners near 90°.
  final maxAngleDev = _maxCornerAngleDeviationFrom90(corners);
  if (maxAngleDev > 36) return ShapeMatch.none;

  // Square snapping: if aspect ratio roughly 1:1, snap to perfect square.
  final edge1 = (corners[1] - corners[0]).distance;
  final edge2 = (corners[2] - corners[1]).distance;
  final longer = math.max(edge1, edge2);
  final shorter = math.min(edge1, edge2);
  final aspect = longer > 0 ? shorter / longer : 1.0;

  List<Offset> finalPoints;
  if (aspect >= 0.84) {
    finalPoints = _makeSquare(corners);
  } else {
    finalPoints = corners;
  }

  // Edge-coverage check: a real rectangle has points along all 4 edges.
  // A scribble may accidentally form 4 corners but will miss entire edges.
  final edgeCoverThreshold = diagonal * 0.14;
  for (int i = 0; i < 4; i++) {
    final a = finalPoints[i];
    final b = finalPoints[(i + 1) % 4];
    bool anyNear = false;
    for (final p in cleaned) {
      if (_pointToSegmentDist(p, a, b) < edgeCoverThreshold) {
        anyNear = true;
        break;
      }
    }
    if (!anyNear) return ShapeMatch.none;
  }

  // Point-to-edge coverage fraction: a real rectangle has most points near
  // one of its 4 edges. A scribble has points scattered inside/outside.
  int nearEdgeCount = 0;
  for (final p in cleaned) {
    double minEdgeDist = double.infinity;
    for (int i = 0; i < 4; i++) {
      final a = finalPoints[i];
      final b = finalPoints[(i + 1) % 4];
      final d = _pointToSegmentDist(p, a, b);
      if (d < minEdgeDist) minEdgeDist = d;
    }
    if (minEdgeDist < edgeCoverThreshold) nearEdgeCount++;
  }
  if (cleaned.isNotEmpty && nearEdgeCount / cleaned.length < 0.50) {
    return ShapeMatch.none;
  }

  // Turn-angle straightness: a real rectangle goes straight most of the time
  // (turns near 0°) with only 4 corner turns near 90°. A scribble turns
  // constantly in random directions.
  int straightTurns = 0;
  int totalTurns = 0;
  for (int i = 1; i < normalized.length - 1; i++) {
    final a = normalized[i - 1];
    final b = normalized[i];
    final c = normalized[i + 1];
    final v1 = Offset(b.dx - a.dx, b.dy - a.dy);
    final v2 = Offset(c.dx - b.dx, c.dy - b.dy);
    if (v1.distance == 0 || v2.distance == 0) continue;
    totalTurns++;
    if (_angleBetweenDeg(v1, v2) < 25.0) straightTurns++;
  }
  if (totalTurns > 0 && straightTurns / totalTurns < 0.55) {
    return ShapeMatch.none;
  }

  final meanDist = _meanDistanceToPolygonEdges(cleaned, finalPoints);
  final distRatio = diagonal > 0 ? meanDist / diagonal : 1.0;
  final fitConfidence = (1.0 - (distRatio / 0.18)).clamp(0.0, 1.0);
  final angleConfidence = (1.0 - (maxAngleDev / 36)).clamp(0.0, 1.0);
  final closureConfidence =
      (1.0 - (closedGap / (diagonal > 0 ? diagonal : 1.0))).clamp(0.0, 1.0);

  final confidence =
      (angleConfidence * 0.45 + closureConfidence * 0.25 + fitConfidence * 0.30)
          .clamp(0.0, 1.0);

  final closed = [...finalPoints, finalPoints.first];
  return ShapeMatch(RecognizedShape.rectangle, closed, confidence);
}

/// Build a perfect square from an oriented rectangle's corners.
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
  ];
}

// ---------------------------------------------------------------------------
// Triangle: 3 dominant corners via RDP + corner clustering
// ---------------------------------------------------------------------------

/// Ramer–Douglas–Peucker polyline simplification.
List<Offset> _simplifyRDP(List<Offset> points, double epsilon) {
  if (points.length < 3) return points;

  double maxDist = 0;
  int index = 0;
  final start = points.first;
  final end = points.last;

  for (int i = 1; i < points.length - 1; i++) {
    final dist = _pointToSegmentDist(points[i], start, end);
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

/// Merge consecutive vertices whose turn angle is below [minTurnDeg].
List<Offset> _mergeCollinear(List<Offset> pts, {double minTurnDeg = 22}) {
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

/// Cluster [vertices] down to [target] corners by repeatedly merging the
/// closest adjacent pair.
List<Offset> _clusterToNCorners(List<Offset> vertices, int target, Rect bounds) {
  final pts = List<Offset>.from(vertices);
  if (pts.isNotEmpty && pts.first == pts.last) pts.removeLast();
  if (pts.length <= target) return pts;

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

/// Check if corners are near-equilateral and snap to a perfect equilateral
/// triangle; otherwise return as-is.
List<Offset> _snapTriangle(List<Offset> corners) {
  final a = corners[0];
  final b = corners[1];
  final c = corners[2];

  final dAB = (b - a).distance;
  final dBC = (c - b).distance;
  final dCA = (a - c).distance;

  final maxSide = math.max(dAB, math.max(dBC, dCA));
  final minSide = math.min(dAB, math.min(dBC, dCA));
  if ((maxSide - minSide) / (maxSide > 0 ? maxSide : 1) < 0.18) {
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

ShapeMatch _matchTriangleNormalized(List<Offset> normalized, List<Offset> cleaned,
    Rect bounds, double diagonal, double closedGap) {
  final simplified = _mergeCollinear(
    _simplifyRDP(cleaned, diagonal * 0.035),
    minTurnDeg: 22,
  );
  final cornerCount = simplified.length - 1;

  List<Offset> corners;
  if (cornerCount == 3) {
    corners = simplified.take(3).toList();
  } else if (cornerCount == 4) {
    // If 4 corners form a clean rectangle, do NOT classify as triangle.
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
  if (angleDev > 36) return ShapeMatch.none;

  final meanDist = _meanDistanceToPolygonEdges(cleaned, corners);
  final distRatio = diagonal > 0 ? meanDist / diagonal : 1.0;
  if (distRatio > 0.17) return ShapeMatch.none;

  final closureConfidence =
      (1.0 - (closedGap / (diagonal > 0 ? diagonal : 1.0))).clamp(0.0, 1.0);
  final fitConfidence = (1.0 - (distRatio / 0.17)).clamp(0.0, 1.0);
  final angleConfidence = (1.0 - (angleDev / 36)).clamp(0.0, 1.0);

  final confidence =
      (fitConfidence * 0.50 + closureConfidence * 0.30 + angleConfidence * 0.20)
          .clamp(0.0, 1.0);

  final snappedCorners = _snapTriangle(corners);
  final closed = [...snappedCorners, snappedCorners.first];
  return ShapeMatch(RecognizedShape.triangle, closed, confidence);
}

// ---------------------------------------------------------------------------
// Star: 5 outer peaks + 5 inner valleys at 72° polar sectors
// ---------------------------------------------------------------------------

ShapeMatch _matchStarNormalized(List<Offset> normalized, List<Offset> cleaned,
    Rect bounds, double diagonal) {
  final centroid = _centroidOf(cleaned);
  final distances = [for (final p in cleaned) (p - centroid).distance];
  final maxDist = distances.reduce(math.max);
  final minDist = distances.reduce(math.min);
  if (maxDist < 14) return ShapeMatch.none;

  // An authentic star has outer points and inner valleys.
  if (minDist / maxDist > 0.62) return ShapeMatch.none;

  // Subdivide the 360° circle into 5 sectors of 72° each.
  final sectorPeaks = List<double>.filled(5, 0.0);
  for (final p in cleaned) {
    var angle = (p - centroid).direction; // [-pi, pi]
    if (angle < 0) angle += 2 * math.pi; // [0, 2pi]
    final sector = ((angle / (2 * math.pi)) * 5).floor().clamp(0, 4);
    final dist = (p - centroid).distance;
    if (dist > sectorPeaks[sector]) {
      sectorPeaks[sector] = dist;
    }
  }

  // All 5 sectors must have a peak reaching near maxDist.
  final allSectorsHaveApex = sectorPeaks.every((p) => p >= maxDist * 0.72);
  if (!allSectorsHaveApex) return ShapeMatch.none;

  // Valley check: between each pair of peaks (at 36° + k*72°), there must be
  // points near the inner radius. A scribble with 5 random lobes won't have
  // clear valleys.
  final outerRadius = math.min(bounds.width, bounds.height) / 2;
  final innerThreshold = outerRadius * 0.75;
  final valleyAngles = [36.0, 108.0, 180.0, 252.0, 324.0];
  for (final valleyDeg in valleyAngles) {
    final valleyRad = valleyDeg * math.pi / 180;
    final vec = Offset(math.cos(valleyRad), math.sin(valleyRad));
    bool hasValleyPoint = false;
    for (final p in cleaned) {
      final rel = p - centroid;
      // Dot product with valley direction: positive means near this angle.
      final alignment = (rel.dx * vec.dx + rel.dy * vec.dy) / rel.distance;
      if (alignment > 0.85) {
        // Within ~32° of the valley angle.
        if (rel.distance < innerThreshold) {
          hasValleyPoint = true;
          break;
        }
      }
    }
    if (!hasValleyPoint) return ShapeMatch.none;
  }

  // Angular concentration: a real star's points cluster on ~10 narrow rays.
  // A scribble spreads across nearly all 36 ten-degree bins around centroid.
  int occupiedBins = 0;
  for (int bin = 0; bin < 36; bin++) {
    final binStart = bin * 10.0;
    final binEnd = binStart + 10.0;
    bool hasPoint = false;
    for (final p in cleaned) {
      var angle = (p - centroid).direction * 180 / math.pi;
      if (angle < 0) angle += 360;
      if (angle >= binStart && angle < binEnd) {
        hasPoint = true;
        break;
      }
    }
    if (hasPoint) occupiedBins++;
  }
  // Real star: ~10-15 bins. Scribble: most of 36.
  if (occupiedBins > 18) return ShapeMatch.none;

  final starPoints = _generateStar(centroid, outerRadius);

  // Star residual: points should lie near the star's 10 edges. A scribble
  // with 5 polar lobes won't follow the star's edge paths.
  final starResidual = _meanDistanceToPolygonEdges(cleaned, starPoints);
  final starDistRatio = diagonal > 0 ? starResidual / diagonal : 1.0;
  if (starDistRatio > 0.20) return ShapeMatch.none;

  final starConfidence =
      (1.0 - (starDistRatio / 0.20)).clamp(0.40, 0.90);
  return ShapeMatch(RecognizedShape.star, starPoints, starConfidence);
}

// ---------------------------------------------------------------------------
// Geometry generators (ideal output geometry)
// ---------------------------------------------------------------------------

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
