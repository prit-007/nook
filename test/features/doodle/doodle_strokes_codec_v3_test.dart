import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_shape_fit.dart';
import 'package:nook/features/doodle/doodle_shape_recognizer.dart';
import 'package:nook/features/doodle/doodle_strokes_codec.dart';

void main() {
  group('DoodleStrokesCodec v3 — fit serialization round-trip', () {
    test('encodes and decodes a LineFit stroke', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(Offset(10, 20), pressure: 0.8),
          StrokePoint(Offset(110, 20), pressure: 0.8),
        ],
        isPerfectShape: true,
        shapeType: RecognizedShape.line,
        recognitionConfidence: 0.85,
        fit: const LineFit(start: Offset(10, 20), end: Offset(110, 20)),
        originalPoints: const [
          Offset(10, 22),
          Offset(55, 18),
          Offset(110, 20),
        ],
      );

      final json = DoodleStrokesCodec.encode([stroke]);
      final data = DoodleStrokesCodec.decode(json);

      expect(data.strokes.length, 1);
      final decoded = data.strokes.first;
      expect(decoded.isPerfectShape, isTrue);
      expect(decoded.shapeType, RecognizedShape.line);
      expect(decoded.recognitionConfidence, 0.85);
      expect(decoded.fit, isA<LineFit>());
      expect((decoded.fit as LineFit).start, Offset(10, 20));
      expect((decoded.fit as LineFit).end, Offset(110, 20));
      expect(decoded.originalPoints, hasLength(3));
      expect(decoded.originalPoints!.first, Offset(10, 22));
      expect(decoded.points.length, 2);
    });

    test('encodes and decodes a RectFit stroke', () {
      final stroke = Stroke(
        points: const [StrokePoint(Offset(0, 0)), StrokePoint(Offset(200, 0))],
        isPerfectShape: true,
        shapeType: RecognizedShape.rectangle,
        recognitionConfidence: 0.9,
        fit: RectFit(
          center: Offset(100, 60),
          uAxis: Offset(1, 0),
          vAxis: Offset(0, 1),
          halfWidth: 100,
          halfHeight: 60,
        ),
      );

      final json = DoodleStrokesCodec.encode([stroke]);
      final data = DoodleStrokesCodec.decode(json);

      final decoded = data.strokes.first;
      expect(decoded.shapeType, RecognizedShape.rectangle);
      expect(decoded.fit, isA<RectFit>());
      final fit = decoded.fit as RectFit;
      expect(fit.center, Offset(100, 60));
      expect(fit.halfWidth, 100);
      expect(fit.halfHeight, 60);
    });

    test('encodes and decodes an OvalFit stroke', () {
      final stroke = Stroke(
        points: const [StrokePoint(Offset(0, 0)), StrokePoint(Offset(120, 0))],
        isPerfectShape: true,
        shapeType: RecognizedShape.oval,
        recognitionConfidence: 0.88,
        fit: const OvalFit(center: Offset(60, 40), rx: 60, ry: 40),
      );

      final json = DoodleStrokesCodec.encode([stroke]);
      final data = DoodleStrokesCodec.decode(json);

      final decoded = data.strokes.first;
      expect(decoded.shapeType, RecognizedShape.oval);
      expect(decoded.fit, isA<OvalFit>());
      final fit = decoded.fit as OvalFit;
      expect(fit.center, Offset(60, 40));
      expect(fit.rx, 60);
      expect(fit.ry, 40);
    });

    test('encodes and decodes a TriangleFit stroke', () {
      final stroke = Stroke(
        points: const [StrokePoint(Offset(0, 0)), StrokePoint(Offset(100, 0))],
        isPerfectShape: true,
        shapeType: RecognizedShape.triangle,
        recognitionConfidence: 0.82,
        fit: TriangleFit(
          a: Offset(100, 0),
          b: Offset(200, 173),
          c: Offset(0, 173),
        ),
      );

      final json = DoodleStrokesCodec.encode([stroke]);
      final data = DoodleStrokesCodec.decode(json);

      final decoded = data.strokes.first;
      expect(decoded.shapeType, RecognizedShape.triangle);
      expect(decoded.fit, isA<TriangleFit>());
      final fit = decoded.fit as TriangleFit;
      expect(fit.a, Offset(100, 0));
      expect(fit.b, Offset(200, 173));
      expect(fit.c, Offset(0, 173));
    });

    test('encodes and decodes a StarFit stroke', () {
      final stroke = Stroke(
        points: const [StrokePoint(Offset(0, 0))],
        isPerfectShape: true,
        shapeType: RecognizedShape.star,
        recognitionConfidence: 0.90,
        fit: const StarFit(center: Offset(200, 200), outerRadius: 80),
      );

      final json = DoodleStrokesCodec.encode([stroke]);
      final data = DoodleStrokesCodec.decode(json);

      final decoded = data.strokes.first;
      expect(decoded.shapeType, RecognizedShape.star);
      expect(decoded.fit, isA<StarFit>());
      final fit = decoded.fit as StarFit;
      expect(fit.center, Offset(200, 200));
      expect(fit.outerRadius, 80);
    });

    test('encodes and decodes a NoneFit (freehand) stroke', () {
      final stroke = Stroke(
        points: const [StrokePoint(Offset(0, 0)), StrokePoint(Offset(10, 10))],
        isPerfectShape: false,
        shapeType: RecognizedShape.none,
        recognitionConfidence: null,
        fit: const NoneFit(),
      );

      final json = DoodleStrokesCodec.encode([stroke]);
      final data = DoodleStrokesCodec.decode(json);

      final decoded = data.strokes.first;
      expect(decoded.isPerfectShape, isFalse);
      expect(decoded.shapeType, RecognizedShape.none);
      expect(decoded.recognitionConfidence, isNull);
      // NoneFit is semantically "no fit" — omitted for non-perfect strokes,
      // so decode returns null (equivalent to NoneFit).
      expect(decoded.fit, isNull);
    });

    test('mixed strokes encode and decode correctly', () {
      final strokes = [
        Stroke(
          points: const [StrokePoint(Offset(0, 0)), StrokePoint(Offset(50, 0))],
          isPerfectShape: true,
          shapeType: RecognizedShape.line,
          recognitionConfidence: 0.8,
          fit: const LineFit(start: Offset(0, 0), end: Offset(50, 0)),
        ),
        Stroke(
          points: const [StrokePoint(Offset(0, 0)), StrokePoint(Offset(30, 30))],
          isPerfectShape: false,
          shapeType: RecognizedShape.none,
          recognitionConfidence: null,
          fit: const NoneFit(),
        ),
      ];

      final json = DoodleStrokesCodec.encode(strokes);
      final data = DoodleStrokesCodec.decode(json);

      expect(data.strokes.length, 2);
      expect(data.strokes[0].shapeType, RecognizedShape.line);
      expect(data.strokes[0].fit, isA<LineFit>());
      expect(data.strokes[1].shapeType, RecognizedShape.none);
      // NoneFit is omitted for non-perfect strokes → decode returns null.
      expect(data.strokes[1].fit, isNull);
    });

    test('encode preserves background', () {
      final json = DoodleStrokesCodec.encode(
        const [],
        background: DoodleBackground.graph,
      );
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['background'], 'graph');
    });

    test('decode preserves background', () {
      const json = '{"version":3,"background":"ruled","strokes":[]}';
      final data = DoodleStrokesCodec.decode(json);
      expect(data.background, DoodleBackground.ruled);
    });

    test('decode handles missing version field gracefully', () {
      const json = '{"background":"dotted","strokes":[]}';
      final data = DoodleStrokesCodec.decode(json);
      expect(data.background, DoodleBackground.dotted);
      expect(data.strokes, isEmpty);
    });

    test('decode handles invalid JSON returns empty', () {
      final data = DoodleStrokesCodec.decode('not json');
      expect(data.strokes, isEmpty);
      expect(data.background, DoodleBackground.dotted);
    });
  });

  group('DoodleStrokesCodec v3 — backward compatibility with v2', () {
    test('decodes v2 JSON without fit field', () {
      const v2Json = '''{
        "version": 2,
        "background": "dotted",
        "strokes": [
          {
            "tool": "pen",
            "color": 4294967295,
            "width": 4.0,
            "opacity": 1.0,
            "isPerfectShape": true,
            "shapeType": "rectangle",
            "points": [[0, 0, 1.0], [200, 0, 1.0]]
          }
        ]
      }''';

      final data = DoodleStrokesCodec.decode(v2Json);
      final stroke = data.strokes.first;
      expect(stroke.shapeType, RecognizedShape.rectangle);
      expect(stroke.isPerfectShape, isTrue);
      // No fit in v2 → fit is null, but shapeType preserved
      expect(stroke.fit, isNull);
      expect(stroke.recognitionConfidence, isNull);
      expect(stroke.originalPoints, isNull);
    });

    test('decodes v1 JSON with perfectShape field', () {
      const v1Json = '''{
        "version": 1,
        "background": "dotted",
        "strokes": [
          {
            "tool": "pen",
            "color": 4294967295,
            "width": 4.0,
            "opacity": 1.0,
            "perfectShape": true,
            "shapeType": "line",
            "points": [[0, 0, 1.0], [100, 0, 1.0]]
          }
        ]
      }''';

      final data = DoodleStrokesCodec.decode(v1Json);
      final stroke = data.strokes.first;
      expect(stroke.isPerfectShape, isTrue);
      expect(stroke.shapeType, RecognizedShape.line);
    });

    test('v2-encoded strokes still decode', () {
      // Simulate v2 encoding by manually constructing v2 JSON
      const v2Json = '''{
        "version": 2,
        "background": "graph",
        "strokes": [
          {
            "tool": "highlighter",
            "color": 4278190080,
            "width": 8.0,
            "opacity": 0.35,
            "isPerfectShape": false,
            "shapeType": "none",
            "points": [[10, 10, 0.5], [20, 20, 0.7]]
          }
        ]
      }''';

      final data = DoodleStrokesCodec.decode(v2Json);
      expect(data.strokes.length, 1);
      expect(data.strokes.first.tool, DoodleTool.highlighter);
      expect(data.strokes.first.width, 8.0);
      expect(data.strokes.first.opacity, 0.35);
    });

    test('round-trip preserves all fields', () {
      final stroke = Stroke(
        points: const [
          StrokePoint(Offset(5.5, 10.25), pressure: 0.6),
          StrokePoint(Offset(95.5, 100.75), pressure: 0.9),
        ],
        color: const Color(0xFFCC0000),
        width: 6.0,
        tool: DoodleTool.pen,
        opacity: 0.9,
        isPerfectShape: true,
        shapeType: RecognizedShape.oval,
        recognitionConfidence: 0.77,
        fit: const OvalFit(center: Offset(50, 55), rx: 45, ry: 45),
        originalPoints: const [
          Offset(5.5, 10.25),
          Offset(50, 55),
          Offset(95.5, 100.75),
        ],
      );

      final json = DoodleStrokesCodec.encode([stroke]);
      final decoded = DoodleStrokesCodec.decode(json).strokes.first;

      expect(decoded.color, const Color(0xFFCC0000));
      expect(decoded.width, 6.0);
      expect(decoded.tool, DoodleTool.pen);
      expect(decoded.opacity, 0.9);
      expect(decoded.isPerfectShape, isTrue);
      expect(decoded.shapeType, RecognizedShape.oval);
      expect(decoded.recognitionConfidence, 0.77);
      expect(decoded.fit, isA<OvalFit>());
      expect((decoded.fit as OvalFit).center, Offset(50, 55));
      expect((decoded.fit as OvalFit).rx, 45);
      expect((decoded.fit as OvalFit).ry, 45);
      expect(decoded.originalPoints, hasLength(3));
      expect(decoded.points.length, 2);
      expect(decoded.points[0].position, Offset(5.5, 10.25));
      expect(decoded.points[0].pressure, 0.6);
    });
  });

  group('DoodleStrokesCodec v3 — encode version field', () {
    test('encode sets version to 3', () {
      final json = DoodleStrokesCodec.encode(const []);
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['version'], 3);
    });

    test('encode includes fit for perfect shapes', () {
      final stroke = Stroke(
        points: const [StrokePoint(Offset(0, 0)), StrokePoint(Offset(50, 0))],
        isPerfectShape: true,
        shapeType: RecognizedShape.line,
        recognitionConfidence: 0.8,
        fit: const LineFit(start: Offset(0, 0), end: Offset(50, 0)),
        originalPoints: const [Offset(0, 1), Offset(25, 5), Offset(50, 0)],
      );
      final json = DoodleStrokesCodec.encode([stroke]);
      final data = jsonDecode(json) as Map<String, dynamic>;
      final strokeMap = data['strokes'][0] as Map<String, dynamic>;
      expect(strokeMap['fit'], isNotNull);
      expect(strokeMap['fit']['type'], 'LineFit');
      expect(strokeMap['recognitionConfidence'], 0.8);
      expect(strokeMap['originalPoints'], isNotNull);
    });

    test('encode omits fit for non-perfect shapes', () {
      final stroke = Stroke(
        points: const [StrokePoint(Offset(0, 0)), StrokePoint(Offset(50, 50))],
        isPerfectShape: false,
        shapeType: RecognizedShape.none,
        recognitionConfidence: null,
        fit: const NoneFit(),
      );
      final json = DoodleStrokesCodec.encode([stroke]);
      final data = jsonDecode(json) as Map<String, dynamic>;
      final strokeMap = data['strokes'][0] as Map<String, dynamic>;
      expect(strokeMap['fit'], isNull);
      expect(strokeMap['recognitionConfidence'], isNull);
    });
  });
}
