import 'dart:math' as math;
import 'dart:ui';

/// Shapes the recognizer can snap a freehand stroke to.
enum RecognizedShape { none, line, arrow, triangle, rectangle, oval, star }

/// Result of attempting to recognize a shape from a raw stroke.
///
/// [points] is the clean, corrected geometry to render in place of the raw
/// hand-drawn points.
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
/// circle/oval, or 5-point star.
///
/// Pipeline:
/// 1. Outlier/hook filtering (strips accidental pen-down/pen-up flick artifacts).
/// 2. Arc-length equidistant resampling to 64 points (speed & sample-rate invariance).
/// 3. Closed vs Open stroke topological classification (endpoint gap & loop overlap).
/// 4. Corner detection via local curvature turning-angle peaks with Non-Maximum Suppression (NMS).
/// 5. Dedicated geometric classification per candidate (Circle/Oval, Triangle,
///    Rectangle/Square, Star, Line, Arrow).
/// 6. Strict validation: non-matching strokes or scribbles return [ShapeMatch.none]
///    instead of falling back to rectangles or lines.
ShapeMatch recognizeShape(List<Offset> raw) {
  if (raw.length < 8) return ShapeMatch.none;

  // 1. Filter pen-down and lift-off flick hooks
  final cleaned = _filterHooks(raw);
  if (cleaned.length < 8) return ShapeMatch.none;

  final bounds = _boundsOf(cleaned);
  final diagonal = Offset(bounds.width, bounds.height).distance;
  if (diagonal < 14.0) return ShapeMatch.none;

  final pathLen = _pathLength(cleaned);
  if (pathLen == 0) return ShapeMatch.none;

  // 2. Arc-length equidistant resampling (64 points)
  final resampled = _resampleArcLength(cleaned, 64);
  final resampledPathLen = _pathLength(resampled);

  // Scribble rejection: a real shape traces its boundary once.
  // A scribble goes back and forth, making path length much larger than perimeter.
  final perimeter = 2 * (bounds.width + bounds.height);
  if (perimeter > 0 && resampledPathLen / perimeter > 3.2) {
    return ShapeMatch.none;
  }

  // 3. Closed vs open stroke determination
  final endGap = (resampled.last - resampled.first).distance;
  final closureRatio = diagonal > 0 ? endGap / diagonal : 1.0;
  final closurePathRatio =
      resampledPathLen > 0 ? endGap / resampledPathLen : 1.0;

  final isClosed = (closureRatio < 0.24 && closurePathRatio < 0.20) ||
      _isLoopOverlap(resampled, diagonal);

  // 4. Corner detection via curvature turning angles
  final corners = _detectCorners(resampled, isClosed, diagonal);

  // 5. Circularity / Isoperimetric Quotient: 4 * pi * Area / Perimeter^2
  final area = isClosed ? _polygonArea(resampled).abs() : 0.0;
  final circularity = resampledPathLen > 0
      ? (4 * math.pi * area) / (resampledPathLen * resampledPathLen)
      : 0.0;

  final candidates = <ShapeMatch>[];

  // --- Open stroke candidates: Line, Arrow ---
  if (!isClosed) {
    final arrowMatch = _matchArrow(
      cleaned: cleaned,
      diagonal: diagonal,
    );
    if (arrowMatch.isRecognized) candidates.add(arrowMatch);

    final lineMatch = _matchLine(
      cleaned: cleaned,
      resampled: resampled,
      diagonal: diagonal,
    );
    if (lineMatch.isRecognized) candidates.add(lineMatch);
  }

  // --- Closed stroke candidates: Circle/Oval, Triangle, Rectangle/Square, Star ---
  if (isClosed) {
    // A. Circle or Oval
    final circleOvalMatch = _matchCircleOrOval(
      resampled: resampled,
      cleaned: cleaned,
      bounds: bounds,
      diagonal: diagonal,
      corners: corners,
      circularity: circularity,
    );
    if (circleOvalMatch.isRecognized) candidates.add(circleOvalMatch);

    // B. Triangle
    final triangleMatch = _matchTriangle(
      resampled: resampled,
      cleaned: cleaned,
      bounds: bounds,
      diagonal: diagonal,
      corners: corners,
      circularity: circularity,
    );
    if (triangleMatch.isRecognized) candidates.add(triangleMatch);

    // C. Rectangle / Square
    final rectMatch = _matchRectangle(
      resampled: resampled,
      cleaned: cleaned,
      bounds: bounds,
      diagonal: diagonal,
      corners: corners,
      circularity: circularity,
    );
    if (rectMatch.isRecognized) candidates.add(rectMatch);

    // D. Star
    final starMatch = _matchStar(
      resampled: resampled,
      cleaned: cleaned,
      bounds: bounds,
      diagonal: diagonal,
      corners: corners,
    );
    if (starMatch.isRecognized) candidates.add(starMatch);
  }

  if (candidates.isEmpty) return ShapeMatch.none;

  candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
  final best = candidates.first;

  // Global confidence threshold: below this, the stroke is freehand ink.
  if (best.confidence < 0.50) return ShapeMatch.none;

  // Prefer arrow over line if arrow has reasonable confidence
  if (best.shape == RecognizedShape.line) {
    for (final c in candidates) {
      if (c.shape == RecognizedShape.arrow &&
          c.confidence > best.confidence - 0.20) {
        return c;
      }
    }
  }

  // Prevent rectangle false-positives over circles/ovals when radial variance is small
  if (best.shape == RecognizedShape.rectangle) {
    for (final c in candidates) {
      if (c.shape == RecognizedShape.oval &&
          c.confidence >= best.confidence - 0.10) {
        return c;
      }
    }
  }

  return best;
}

// ---------------------------------------------------------------------------
// 1. Hook Filtering
// ---------------------------------------------------------------------------

List<Offset> _filterHooks(List<Offset> raw) {
  if (raw.length < 8) return raw;
  final result = List<Offset>.from(raw);

  // Check start hook
  final startSeg = result[1] - result[0];
  final nextSeg = result[2] - result[1];
  if (startSeg.distance < 10.0 && _angleBetweenDeg(startSeg, nextSeg) > 85.0) {
    result.removeAt(0);
  }

  // Check end hook
  final n = result.length;
  if (n >= 8) {
    final endSeg = result[n - 1] - result[n - 2];
    final prevSeg = result[n - 2] - result[n - 3];
    if (endSeg.distance < 10.0 && _angleBetweenDeg(endSeg, prevSeg) > 85.0) {
      result.removeLast();
    }
  }

  return result;
}

// ---------------------------------------------------------------------------
// 2. Arc-Length Equidistant Resampling
// ---------------------------------------------------------------------------

List<Offset> _resampleArcLength(List<Offset> points, int count) {
  if (points.length < 2) return List<Offset>.from(points);

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
    int seg = 0;
    while (seg < lastSeg && distances[seg + 1] < target) {
      seg++;
    }
    seg = seg.clamp(0, lastSeg);
    final segLen = distances[seg + 1] - distances[seg];
    final t = segLen == 0
        ? 0.0
        : ((target - distances[seg]) / segLen).clamp(0.0, 1.0);
    result.add(Offset.lerp(points[seg], points[seg + 1], t)!);
  }
  return result;
}

// ---------------------------------------------------------------------------
// 3. Corner Detection (Curvature & Turning Angles)
// ---------------------------------------------------------------------------

class _Corner {
  const _Corner(this.index, this.angleDeg);
  final int index;
  final double angleDeg;
}

List<_Corner> _detectCorners(List<Offset> pts, bool isClosed, double diagonal) {
  final n = pts.length;
  const k = 3;
  if (n < 12) return [];

  final rawAngles = List<double>.filled(n, 0.0);
  final startI = isClosed ? 0 : k;
  final endI = isClosed ? n : n - k;

  for (int i = startI; i < endI; i++) {
    final prev = pts[(i - k + n) % n];
    final curr = pts[i];
    final next = pts[(i + k) % n];
    final vIn = curr - prev;
    final vOut = next - curr;
    rawAngles[i] = _angleBetweenDeg(vIn, vOut);
  }

  // Smooth angles with 3-point moving average
  final smoothed = List<double>.filled(n, 0.0);
  for (int i = 0; i < n; i++) {
    smoothed[i] = 0.2 * rawAngles[(i - 1 + n) % n] +
        0.6 * rawAngles[i] +
        0.2 * rawAngles[(i + 1) % n];
  }

  // Identify local curvature peaks above 26 degrees
  final candidates = <_Corner>[];
  for (int i = startI; i < endI; i++) {
    final aPrev = smoothed[(i - 1 + n) % n];
    final aCurr = smoothed[i];
    final aNext = smoothed[(i + 1) % n];
    if (aCurr >= 26.0 && aCurr > aPrev && aCurr >= aNext) {
      candidates.add(_Corner(i, aCurr));
    }
  }

  // Non-Maximum Suppression (NMS) by Euclidean distance
  final suppressionDist = diagonal * 0.10;
  candidates.sort((a, b) => b.angleDeg.compareTo(a.angleDeg));
  final result = <_Corner>[];

  for (final cand in candidates) {
    final candPt = pts[cand.index];
    bool suppressed = false;
    for (final kept in result) {
      final keptPt = pts[kept.index];
      if ((candPt - keptPt).distance < suppressionDist) {
        suppressed = true;
        break;
      }
    }
    if (!suppressed) {
      result.add(cand);
    }
  }

  result.sort((a, b) => a.index.compareTo(b.index));
  return result;
}

// ---------------------------------------------------------------------------
// 4. Closed Shape Matchers: Circle/Oval, Triangle, Rectangle/Square, Star
// ---------------------------------------------------------------------------

ShapeMatch _matchCircleOrOval({
  required List<Offset> resampled,
  required List<Offset> cleaned,
  required Rect bounds,
  required double diagonal,
  required List<_Corner> corners,
  required double circularity,
}) {
  // If the stroke has 3 or 4 sharp prominent corners (> 55°), it is a polygon, not an oval.
  final sharpCorners = corners.where((c) => c.angleDeg > 55.0).length;
  if (sharpCorners >= 3) return ShapeMatch.none;

  // Convexity check: Circles and ovals are strictly convex.
  // Any significant concave indentation (like in a kidney/bean, heart, or pac-man) invalidates circle/oval.
  // Convexity check: Circles and ovals are convex.
  final hull = _convexHull(cleaned);
  final strokeArea = _polygonArea(cleaned).abs();
  final hullArea = _polygonArea(hull).abs();
  if (hullArea > 0 && strokeArea / hullArea < 0.80) {
    return ShapeMatch.none;
  }

  final centroid = _centroidOf(resampled);
  final radii = [for (final p in resampled) (p - centroid).distance];
  final meanR = radii.reduce((a, b) => a + b) / radii.length;
  if (meanR < 4.0) return ShapeMatch.none;

  double varSum = 0;
  for (final r in radii) {
    final d = r - meanR;
    varSum += d * d;
  }
  final stdR = math.sqrt(varSum / radii.length);
  final cvR = stdR / meanR;

  final aspectRatio = bounds.width / bounds.height;
  final circleFit = _fitCircle(resampled);

  // Circle classification
  if (circleFit != null && aspectRatio >= 0.74 && aspectRatio <= 1.35) {
    final circleDev = circleFit.residualRms / circleFit.r;
    if (circleDev <= 0.19 && cvR <= 0.17) {
      final fitScore = (1.0 - (circleDev / 0.19)).clamp(0.0, 1.0);
      final varScore = (1.0 - (cvR / 0.17)).clamp(0.0, 1.0);
      var confidence = (fitScore * 0.6 + varScore * 0.4).clamp(0.55, 0.98);
      if (aspectRatio >= 0.85 && aspectRatio <= 1.18) {
        confidence = math.min(1.0, confidence + 0.05);
      }
      final radius = (bounds.width + bounds.height) / 4;
      return ShapeMatch(
        RecognizedShape.oval,
        _generateCircle(Offset(circleFit.cx, circleFit.cy), radius),
        confidence,
      );
    }
  }

  // Oval / Ellipse classification
  final rx = bounds.width / 2;
  final ry = bounds.height / 2;
  if (rx >= 5.0 && ry >= 5.0) {
    double ellipseDevSum = 0;
    for (final p in resampled) {
      final ndx = (p.dx - centroid.dx) / rx;
      final ndy = (p.dy - centroid.dy) / ry;
      ellipseDevSum += (math.sqrt(ndx * ndx + ndy * ndy) - 1.0).abs();
    }
    final meanEllipseDev = ellipseDevSum / resampled.length;
    if (meanEllipseDev <= 0.11) {
      final confidence = (1.0 - (meanEllipseDev / 0.11)).clamp(0.50, 0.95);
      return ShapeMatch(
        RecognizedShape.oval,
        _generateOval(bounds),
        confidence,
      );
    }
  }

  return ShapeMatch.none;
}

ShapeMatch _matchTriangle({
  required List<Offset> resampled,
  required List<Offset> cleaned,
  required Rect bounds,
  required double diagonal,
  required List<_Corner> corners,
  required double circularity,
}) {
  if (circularity > 0.76) return ShapeMatch.none;

  List<Offset> vertices = [];
  if (corners.length == 3) {
    vertices = corners.map((c) => resampled[c.index]).toList();
  } else {
    // Polyline simplification with RDP
    final simplified = _mergeCollinear(
      _simplifyRDP(cleaned, diagonal * 0.04),
      minTurnDeg: 24,
    );
    final pts = List<Offset>.from(simplified);
    if (pts.isNotEmpty && pts.first == pts.last) pts.removeLast();
    if (pts.length == 3) {
      vertices = pts;
    } else if (pts.length == 4 && corners.length != 4) {
      // If 4 corners form a rectangle with right angles, do NOT force into triangle!
      if (_maxCornerAngleDevFrom90(pts) <= 26.0) {
        return ShapeMatch.none;
      }
      vertices = _clusterToNCorners(pts, 3, bounds);
    } else if (corners.length > 3) {
      final top3 = List<_Corner>.from(corners)
        ..sort((a, b) => b.angleDeg.compareTo(a.angleDeg));
      final top3Corners = top3.take(3).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      vertices = top3Corners.map((c) => resampled[c.index]).toList();
    }
  }

  if (vertices.length != 3) return ShapeMatch.none;

  final angleSum = _interiorAngleSumDeg(vertices);
  final angleDev = (angleSum - 180.0).abs();
  if (angleDev > 35.0) return ShapeMatch.none;

  for (int i = 0; i < 3; i++) {
    final a = vertices[(i - 1 + 3) % 3];
    final b = vertices[i];
    final c = vertices[(i + 1) % 3];
    final ang = _angleBetweenDeg(a - b, c - b);
    if (ang < 15.0 || ang > 150.0) return ShapeMatch.none;
  }

  final meanEdgeDist = _meanDistanceToPolygonEdges(resampled, vertices);
  final distRatio = diagonal > 0 ? meanEdgeDist / diagonal : 1.0;
  if (distRatio > 0.13) return ShapeMatch.none;

  final triArea = _polygonArea(vertices).abs();
  final boxArea = bounds.width * bounds.height;
  if (boxArea > 0) {
    final fill = triArea / boxArea;
    if (fill < 0.18 || fill > 0.72) return ShapeMatch.none;
  }

  final fitScore = (1.0 - (distRatio / 0.13)).clamp(0.0, 1.0);
  final angleScore = (1.0 - (angleDev / 35.0)).clamp(0.0, 1.0);
  final confidence = (fitScore * 0.6 + angleScore * 0.4).clamp(0.55, 0.98);

  final snapped = _snapTriangle(vertices);
  return ShapeMatch(
      RecognizedShape.triangle, [...snapped, snapped.first], confidence);
}

double _maxCornerAngleDevFrom90(List<Offset> corners) {
  if (corners.length != 4) return 999.0;
  double maxDev = 0;
  for (int i = 0; i < 4; i++) {
    final a = corners[(i - 1 + 4) % 4];
    final b = corners[i];
    final c = corners[(i + 1) % 4];
    final ang = _angleBetweenDeg(a - b, c - b);
    final dev = (ang - 90.0).abs();
    if (dev > maxDev) maxDev = dev;
  }
  return maxDev;
}

ShapeMatch _matchRectangle({
  required List<Offset> resampled,
  required List<Offset> cleaned,
  required Rect bounds,
  required double diagonal,
  required List<_Corner> corners,
  required double circularity,
}) {
  // A rectangle or square cannot have circle-like circularity (theoretical square max is pi/4 ~= 0.785)
  if (circularity > 0.82) return ShapeMatch.none;

  List<Offset> corners4 = [];

  // Strategy A: If _detectCorners found exactly 4 corners
  if (corners.length == 4) {
    final candidatePts = corners.map((c) => resampled[c.index]).toList();
    if (_maxCornerAngleDevFrom90(candidatePts) <= 32.0) {
      corners4 = candidatePts;
    }
  } else if (corners.length == 5) {
    // If start and end overlap produced two corners close together, merge them
    int closeA = -1, closeB = -1;
    final tol = diagonal * 0.16;
    for (int i = 0; i < 5; i++) {
      final nextI = (i + 1) % 5;
      final p1 = resampled[corners[i].index];
      final p2 = resampled[corners[nextI].index];
      if ((p1 - p2).distance < tol) {
        closeA = i;
        closeB = nextI;
        break;
      }
    }
    if (closeA != -1) {
      final merged = <Offset>[];
      for (int i = 0; i < 5; i++) {
        if (i == closeA) {
          final p1 = resampled[corners[closeA].index];
          final p2 = resampled[corners[closeB].index];
          merged.add(Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2));
        } else if (i == closeB) {
          continue;
        } else {
          merged.add(resampled[corners[i].index]);
        }
      }
      if (merged.length == 4 && _maxCornerAngleDevFrom90(merged) <= 32.0) {
        corners4 = merged;
      }
    }
  }

  // Strategy B: Polyline simplification via RDP
  if (corners4.length != 4) {
    final simplified = _mergeCollinear(
      _simplifyRDP(cleaned, diagonal * 0.04),
      minTurnDeg: 24,
    );
    final pts = List<Offset>.from(simplified);
    if (pts.isNotEmpty && (pts.first - pts.last).distance < diagonal * 0.10) {
      pts.removeLast();
    }
    if (pts.length == 4 && _maxCornerAngleDevFrom90(pts) <= 32.0) {
      corners4 = pts;
    }
  }

  // Strategy C: Prominent corners from curvature when extra wobbles exist
  if (corners4.length != 4 && corners.length > 4) {
    final top4 = List<_Corner>.from(corners)
      ..sort((a, b) => b.angleDeg.compareTo(a.angleDeg));
    if (top4[3].angleDeg >= 38.0) {
      final top4ByIndex = top4.take(4).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      final candidatePts = top4ByIndex.map((c) => resampled[c.index]).toList();
      if (_maxCornerAngleDevFrom90(candidatePts) <= 30.0) {
        corners4 = candidatePts;
      }
    }
  }

  if (corners4.length != 4) return ShapeMatch.none;

  // Strict convexity check: all cross products must share the same sign
  bool? positiveSign;
  for (int i = 0; i < 4; i++) {
    final a = corners4[(i - 1 + 4) % 4];
    final b = corners4[i];
    final c = corners4[(i + 1) % 4];
    final cross = (b.dx - a.dx) * (c.dy - b.dy) - (b.dy - a.dy) * (c.dx - b.dx);
    if (cross.abs() < 1e-4) continue;
    final isPos = cross > 0;
    if (positiveSign == null) {
      positiveSign = isPos;
    } else if (positiveSign != isPos) {
      return ShapeMatch.none;
    }
  }

  // Verify corner interior angles are near 90°
  final maxAngleDev = _maxCornerAngleDevFrom90(corners4);
  if (maxAngleDev > 30.0) return ShapeMatch.none;

  // Verify side lengths are non-trivial
  for (int i = 0; i < 4; i++) {
    final side = (corners4[(i + 1) % 4] - corners4[i]).distance;
    if (side < diagonal * 0.08) return ShapeMatch.none;
  }

  // Area & Fill factor checks
  final quadArea = _polygonArea(corners4).abs();
  final side1 = (corners4[1] - corners4[0]).distance;
  final side2 = (corners4[2] - corners4[1]).distance;
  final expectedBoxArea = side1 * side2;
  if (expectedBoxArea > 0) {
    final fillRatio = quadArea / expectedBoxArea;
    if (fillRatio < 0.78 || fillRatio > 1.25) return ShapeMatch.none;
  }

  final strokeArea = _polygonArea(cleaned).abs();
  if (quadArea > 0) {
    final strokeFill = strokeArea / quadArea;
    if (strokeFill < 0.74 || strokeFill > 1.28) return ShapeMatch.none;
  }

  // Mean distance to polygon edges must be small
  final meanDist = _meanDistanceToPolygonEdges(resampled, corners4);
  final distRatio = diagonal > 0 ? meanDist / diagonal : 1.0;
  if (distRatio > 0.11) return ShapeMatch.none;

  // Square snapping:
  final longer = math.max(side1, side2);
  final shorter = math.min(side1, side2);
  final aspect = longer > 0 ? shorter / longer : 1.0;

  List<Offset> finalPoints;
  if (aspect >= 0.82) {
    finalPoints = _makeSquare(corners4);
  } else {
    finalPoints = _orthogonalizeCorners(corners4);
  }

  final fitScore = (1.0 - (distRatio / 0.11)).clamp(0.0, 1.0);
  final angleScore = (1.0 - (maxAngleDev / 30.0)).clamp(0.0, 1.0);
  final confidence = (fitScore * 0.6 + angleScore * 0.4).clamp(0.55, 0.98);

  return ShapeMatch(RecognizedShape.rectangle,
      [...finalPoints, finalPoints.first], confidence);
}

ShapeMatch _matchStar({
  required List<Offset> resampled,
  required List<Offset> cleaned,
  required Rect bounds,
  required double diagonal,
  required List<_Corner> corners,
}) {
  // A star must have multiple sharp turns / lobes (at least 6 corner peaks)
  if (corners.length < 6) return ShapeMatch.none;

  final centroid = _centroidOf(resampled);
  final radii = [for (final p in resampled) (p - centroid).distance];
  final maxR = radii.reduce(math.max);
  final minR = radii.reduce(math.min);
  if (maxR < 14.0) return ShapeMatch.none;

  final valleyRatio = minR / maxR;
  if (valleyRatio < 0.18 || valleyRatio > 0.60) return ShapeMatch.none;

  final sectorPeaks = List<double>.filled(5, 0.0);
  for (final p in resampled) {
    var angle = (p - centroid).direction;
    if (angle < 0) angle += 2 * math.pi;
    final sector = ((angle / (2 * math.pi)) * 5).floor().clamp(0, 4);
    final dist = (p - centroid).distance;
    if (dist > sectorPeaks[sector]) {
      sectorPeaks[sector] = dist;
    }
  }

  if (!sectorPeaks.every((p) => p >= maxR * 0.68)) return ShapeMatch.none;

  final outerRadius = math.min(bounds.width, bounds.height) / 2;
  final starPoints = _generateStar(centroid, outerRadius);

  final meanDist = _meanDistanceToPolygonEdges(resampled, starPoints);
  final distRatio = diagonal > 0 ? meanDist / diagonal : 1.0;
  if (distRatio > 0.22) return ShapeMatch.none;

  final confidence = (1.0 - (distRatio / 0.22)).clamp(0.50, 0.92);
  return ShapeMatch(RecognizedShape.star, starPoints, confidence);
}

// ---------------------------------------------------------------------------
// 5. Open Shape Matchers: Line, Arrow
// ---------------------------------------------------------------------------

ShapeMatch _matchLine({
  required List<Offset> cleaned,
  required List<Offset> resampled,
  required double diagonal,
}) {
  final start = cleaned.first;
  final end = cleaned.last;
  final directDist = (end - start).distance;
  if (directDist < 12.0) return ShapeMatch.none;

  final pathLen = _pathLength(cleaned);
  final rawStraightness =
      pathLen > 0 ? (directDist / pathLen).clamp(0.0, 1.0) : 0.0;

  final resampledDist = (resampled.last - resampled.first).distance;
  final resampledLen = _pathLength(resampled);
  final resampledStraightness =
      resampledLen > 0 ? (resampledDist / resampledLen).clamp(0.0, 1.0) : 0.0;

  final straightness = math.max(rawStraightness, resampledStraightness);
  if (straightness < 0.84) return ShapeMatch.none;

  double maxPerp = 0;
  for (final p in cleaned) {
    final d = _pointToSegmentDist(p, start, end);
    if (d > maxPerp) maxPerp = d;
  }
  final maxAllowedPerp = directDist * 0.09;
  if (maxPerp > maxAllowedPerp) return ShapeMatch.none;

  final snappedEnd = snapLineAngle(start, end);
  final fitScore = (straightness * 0.7 + (1.0 - maxPerp / maxAllowedPerp) * 0.3)
      .clamp(0.0, 1.0);
  final confidence = fitScore.clamp(0.60, 0.98);

  return ShapeMatch(RecognizedShape.line, [start, snappedEnd], confidence);
}

ShapeMatch _matchArrow({
  required List<Offset> cleaned,
  required double diagonal,
}) {
  if (cleaned.length < 8) return ShapeMatch.none;
  final start = cleaned.first;
  final n = cleaned.length;

  int tipIdx = 0;
  double maxDist = 0;
  for (int i = 0; i < n; i++) {
    final d = (cleaned[i] - start).distance;
    if (d > maxDist) {
      maxDist = d;
      tipIdx = i;
    }
  }

  final minTipIdx = (n * 0.50).floor();
  final maxTipIdx = n - 2;
  if (tipIdx < minTipIdx || tipIdx > maxTipIdx) return ShapeMatch.none;

  final tip = cleaned[tipIdx];
  final shaftPoints = cleaned.sublist(0, tipIdx + 1);
  final shaftPathLen = _pathLength(shaftPoints);
  final shaftDirect = (tip - start).distance;
  if (shaftDirect < diagonal * 0.28) return ShapeMatch.none;

  final shaftStraightness =
      shaftPathLen > 0 ? (shaftDirect / shaftPathLen) : 0.0;
  if (shaftStraightness < 0.76) return ShapeMatch.none;

  final barbVec = cleaned.last - tip;
  if (barbVec.distance < diagonal * 0.05) return ShapeMatch.none;

  final shaftDir = (tip - start) / shaftDirect;
  final backwardShaft = Offset(-shaftDir.dx, -shaftDir.dy);
  final barbDir = barbVec / barbVec.distance;
  final bendDeg = _angleBetweenDeg(backwardShaft, barbDir);
  if (bendDeg < 15.0 || bendDeg > 90.0) return ShapeMatch.none;

  final confidence = (shaftStraightness * 0.6 + 0.35).clamp(0.55, 0.95);
  return ShapeMatch(RecognizedShape.arrow, [start, tip], confidence);
}

// ---------------------------------------------------------------------------
// 6. Geometry Helpers & Output Snapping
// ---------------------------------------------------------------------------

Offset snapLineAngle(Offset start, Offset end) {
  final vec = end - start;
  final dist = vec.distance;
  if (dist < 4) return end;

  var angleDeg = vec.direction * 180 / math.pi;
  if (angleDeg < 0) angleDeg += 360;

  const snapThreshold = 8.0;

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

  // 30° / 60° Isometric angles
  const isoAngles = [30.0, 60.0, 120.0, 150.0, 210.0, 240.0, 300.0, 330.0];
  for (final target in isoAngles) {
    if ((angleDeg - target).abs() <= 6.0) {
      final rad = target * math.pi / 180;
      return Offset(
          start.dx + dist * math.cos(rad), start.dy + dist * math.sin(rad));
    }
  }

  return end;
}

List<Offset> _orthogonalizeCorners(List<Offset> corners) {
  final center = _centroidOf(corners);
  final uVec = (corners[1] - corners[0]) + (corners[2] - corners[3]);
  final uLen = uVec.distance;
  if (uLen == 0) return corners;

  var u = Offset(uVec.dx / uLen, uVec.dy / uLen);
  var angleDeg = u.direction * 180 / math.pi;
  if (angleDeg < 0) angleDeg += 360;

  // Snap orientation to cardinal if within 8 degrees
  const snapTol = 8.0;
  if (angleDeg <= snapTol || angleDeg >= 360 - snapTol) {
    u = const Offset(1, 0);
  } else if ((angleDeg - 90).abs() <= snapTol) {
    u = const Offset(0, 1);
  } else if ((angleDeg - 180).abs() <= snapTol) {
    u = const Offset(-1, 0);
  } else if ((angleDeg - 270).abs() <= snapTol) {
    u = const Offset(0, -1);
  }

  final v = Offset(-u.dy, u.dx);

  final w = ((corners[1] - corners[0]).distance +
          (corners[2] - corners[3]).distance) /
      2;
  final h = ((corners[2] - corners[1]).distance +
          (corners[3] - corners[0]).distance) /
      2;

  final hw = w / 2;
  final hh = h / 2;

  return [
    center - u * hw - v * hh,
    center + u * hw - v * hh,
    center + u * hw + v * hh,
    center - u * hw + v * hh,
  ];
}

List<Offset> _makeSquare(List<Offset> rect) {
  final center = _centroidOf(rect);
  final edge1 = (rect[1] - rect[0]).distance;
  final edge2 = (rect[2] - rect[1]).distance;
  final side = (edge1 + edge2) / 2;

  final uVec = rect[1] - rect[0];
  final uLen = uVec.distance;
  var u =
      uLen > 0 ? Offset(uVec.dx / uLen, uVec.dy / uLen) : const Offset(1, 0);

  var angleDeg = u.direction * 180 / math.pi;
  if (angleDeg < 0) angleDeg += 360;
  const snapTol = 8.0;
  if (angleDeg <= snapTol || angleDeg >= 360 - snapTol) {
    u = const Offset(1, 0);
  } else if ((angleDeg - 90).abs() <= snapTol) {
    u = const Offset(0, 1);
  } else if ((angleDeg - 180).abs() <= snapTol) {
    u = const Offset(-1, 0);
  } else if ((angleDeg - 270).abs() <= snapTol) {
    u = const Offset(0, -1);
  }

  final v = Offset(-u.dy, u.dx);
  final h = side / 2;

  return [
    center - u * h - v * h,
    center + u * h - v * h,
    center + u * h + v * h,
    center - u * h + v * h,
  ];
}

List<Offset> _snapTriangle(List<Offset> corners) {
  if (corners.length != 3) return corners;
  final a = corners[0];
  final b = corners[1];
  final c = corners[2];

  final dAB = (b - a).distance;
  final dBC = (c - b).distance;
  final dCA = (a - c).distance;

  final maxSide = math.max(dAB, math.max(dBC, dCA));
  final minSide = math.min(dAB, math.min(dBC, dCA));

  // Equilateral snapping
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

  // Right-angled triangle snapping: if one corner angle is within 8° of 90°
  for (int i = 0; i < 3; i++) {
    final v0 = corners[i];
    final vPrev = corners[(i - 1 + 3) % 3];
    final vNext = corners[(i + 1) % 3];
    final ang = _angleBetweenDeg(vPrev - v0, vNext - v0);
    if ((ang - 90.0).abs() <= 8.0) {
      final leg1 = vPrev - v0;
      final leg2 = vNext - v0;
      final len1 = leg1.distance;
      final len2 = leg2.distance;
      if (len1 > 0 && len2 > 0) {
        var u = Offset(leg1.dx / len1, leg1.dy / len1);
        final uDeg = (u.direction * 180 / math.pi + 360) % 360;
        if (uDeg <= 8 || uDeg >= 352) {
          u = const Offset(1, 0);
        } else if ((uDeg - 90).abs() <= 8) {
          u = const Offset(0, 1);
        } else if ((uDeg - 180).abs() <= 8) {
          u = const Offset(-1, 0);
        } else if ((uDeg - 270).abs() <= 8) {
          u = const Offset(0, -1);
        }

        var v = Offset(-u.dy, u.dx);
        if (v.dx * leg2.dx + v.dy * leg2.dy < 0) {
          v = Offset(u.dy, -u.dx);
        }

        final snappedPrev = v0 + u * len1;
        final snappedNext = v0 + v * len2;
        final res = List<Offset>.from(corners);
        res[(i - 1 + 3) % 3] = snappedPrev;
        res[(i + 1) % 3] = snappedNext;
        return res;
      }
    }
  }

  return corners;
}

// ---------------------------------------------------------------------------
// 7. Core Polyline & Polygon Math
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

double _polygonArea(List<Offset> points) {
  double sum = 0;
  final n = points.length;
  for (int i = 0; i < n; i++) {
    final a = points[i];
    final b = points[(i + 1) % n];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum / 2.0;
}

double _angleBetweenDeg(Offset a, Offset b) {
  if (a.distance == 0 || b.distance == 0) return 0;
  final dot = (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
  return math.acos(dot.clamp(-1.0, 1.0)) * 180 / math.pi;
}

double _pointToSegmentDist(Offset p, Offset a, Offset b) {
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
      final d = _pointToSegmentDist(p, a, b);
      if (d < minDist) minDist = d;
    }
    totalDist += minDist;
  }
  return totalDist / stroke.length;
}

double _interiorAngleSumDeg(List<Offset> corners) {
  double sum = 0;
  final n = corners.length;
  for (int i = 0; i < n; i++) {
    final a = corners[(i - 1 + n) % n];
    final b = corners[i];
    final c = corners[(i + 1) % n];
    sum += _angleBetweenDeg(a - b, c - b);
  }
  return sum;
}

bool _isLoopOverlap(List<Offset> points, double diagonal) {
  if (points.length < 16) return false;
  final start = points.first;
  final checkStart = (points.length * 0.75).floor();
  for (int i = checkStart; i < points.length; i++) {
    if ((points[i] - start).distance < diagonal * 0.16) {
      return true;
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// 8. RDP Simplification & Collinear Merging
// ---------------------------------------------------------------------------

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

List<Offset> _clusterToNCorners(
    List<Offset> vertices, int target, Rect bounds) {
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

// ---------------------------------------------------------------------------
// 9. Convex Hull & Minimum Rotated Rect
// ---------------------------------------------------------------------------

double _cross(Offset o, Offset a, Offset b) {
  return (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
}

List<Offset> _convexHull(List<Offset> points) {
  if (points.length <= 2) return List<Offset>.from(points);
  final sorted = List<Offset>.from(points)
    ..sort(
        (a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));

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

  return [
    ...lower.sublist(0, lower.length - 1),
    ...upper.sublist(0, upper.length - 1)
  ];
}

// ---------------------------------------------------------------------------
// 10. Circle Fitting (Pratt Algebraic Fit)
// ---------------------------------------------------------------------------

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

  double sumX = 0, sumY = 0, sumX2 = 0, sumY2 = 0, sumXY = 0;
  for (final p in points) {
    sumX += p.dx;
    sumY += p.dy;
    sumX2 += p.dx * p.dx;
    sumY2 += p.dy * p.dy;
    sumXY += p.dx * p.dy;
  }
  final n = points.length.toDouble();

  double sumR2 = 0, sumXR2 = 0, sumYR2 = 0;
  for (final p in points) {
    final r2 = p.dx * p.dx + p.dy * p.dy;
    sumR2 += r2;
    sumXR2 += p.dx * r2;
    sumYR2 += p.dy * r2;
  }

  final m00 = n;
  final m01 = sumX;
  final m02 = sumY;
  final m10 = sumX;
  final m11 = sumX2;
  final m12 = sumXY;
  final m20 = sumY;
  final m21 = sumXY;
  final m22 = sumY2;

  final detM = m00 * (m11 * m22 - m12 * m21) -
      m01 * (m10 * m22 - m12 * m20) +
      m02 * (m10 * m21 - m11 * m20);
  if (detM.abs() < 1e-9) return null;

  final c = (sumR2 * (m11 * m22 - m12 * m21) -
          m01 * (sumXR2 * m22 - m12 * sumYR2) +
          m02 * (sumXR2 * m21 - m11 * sumYR2)) /
      detM;
  final a = (m00 * (sumXR2 * m22 - m12 * sumYR2) -
          sumR2 * (m10 * m22 - m12 * m20) +
          m02 * (m10 * sumYR2 - sumXR2 * m20)) /
      detM;
  final b = (m00 * (m11 * sumYR2 - sumXR2 * m21) -
          m01 * (m10 * sumYR2 - sumXR2 * m20) +
          sumR2 * (m10 * m21 - m11 * m20)) /
      detM;

  final cx = a / 2;
  final cy = b / 2;
  final rSquared = c + (a * a + b * b) / 4;
  if (rSquared <= 0) return null;
  final r = math.sqrt(rSquared);

  double sqSum = 0;
  for (final p in points) {
    final d = (Offset(p.dx - cx, p.dy - cy)).distance;
    final diff = d - r;
    sqSum += diff * diff;
  }
  final residualRms = math.sqrt(sqSum / points.length);

  return _CircleFit(cx: cx, cy: cy, r: r, residualRms: residualRms);
}

// ---------------------------------------------------------------------------
// 11. Geometry Generators (Ideal Output Shapes)
// ---------------------------------------------------------------------------

List<Offset> _generateStar(Offset center, double outerRadius) {
  final innerRadius = outerRadius * 0.40;
  final points = <Offset>[];
  const startAngle = -math.pi / 2;

  for (int i = 0; i < 10; i++) {
    final angle = startAngle + (i * math.pi / 5);
    final r = (i % 2 == 0) ? outerRadius : innerRadius;
    points.add(center + Offset(math.cos(angle) * r, math.sin(angle) * r));
  }
  points.add(points.first);
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
