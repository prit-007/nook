import 'dart:convert';

import 'package:flutter/painting.dart';

import 'doodle_controller.dart';
import 'doodle_shape_fit.dart';
import 'doodle_shape_recognizer.dart';

/// A saved doodle: its strokes plus the background template it was drawn on.
class DoodleData {
  const DoodleData({
    this.strokes = const [],
    this.background = DoodleBackground.dotted,
  });

  final List<Stroke> strokes;
  final DoodleBackground background;
}

/// Serializes doodle strokes to/from JSON for persistence.
class DoodleStrokesCodec {
  DoodleStrokesCodec._();

  static const int _version = 3;

  static Map<String, dynamic>? _encodeFit(ShapeFit? fit) {
    if (fit == null) return null;

    if (fit is LineFit) {
      return {
        'type': 'LineFit',
        'start': [fit.start.dx, fit.start.dy],
        'end': [fit.end.dx, fit.end.dy],
      };
    }
    if (fit is RectFit) {
      return {
        'type': 'RectFit',
        'center': [fit.center.dx, fit.center.dy],
        'uAxis': [fit.uAxis.dx, fit.uAxis.dy],
        'vAxis': [fit.vAxis.dx, fit.vAxis.dy],
        'halfWidth': fit.halfWidth,
        'halfHeight': fit.halfHeight,
      };
    }
    if (fit is OvalFit) {
      return {
        'type': 'OvalFit',
        'center': [fit.center.dx, fit.center.dy],
        'rx': fit.rx,
        'ry': fit.ry,
      };
    }
    if (fit is TriangleFit) {
      return {
        'type': 'TriangleFit',
        'a': [fit.a.dx, fit.a.dy],
        'b': [fit.b.dx, fit.b.dy],
        'c': [fit.c.dx, fit.c.dy],
      };
    }
    if (fit is StarFit) {
      return {
        'type': 'StarFit',
        'center': [fit.center.dx, fit.center.dy],
        'outerRadius': fit.outerRadius,
      };
    }
    if (fit is NoneFit) {
      return {'type': 'NoneFit'};
    }
    return null;
  }

  static ShapeFit? _decodeFit(Map<String, dynamic>? map) {
    if (map == null) return null;

    final type = map['type'] as String?;
    switch (type) {
      case 'LineFit':
        return LineFit(
          start: Offset(map['start'][0].toDouble(), map['start'][1].toDouble()),
          end: Offset(map['end'][0].toDouble(), map['end'][1].toDouble()),
        );
      case 'RectFit':
        return RectFit(
          center: Offset(
              map['center'][0].toDouble(), map['center'][1].toDouble()),
          uAxis: Offset(
              map['uAxis'][0].toDouble(), map['uAxis'][1].toDouble()),
          vAxis: Offset(
              map['vAxis'][0].toDouble(), map['vAxis'][1].toDouble()),
          halfWidth: (map['halfWidth'] as num).toDouble(),
          halfHeight: (map['halfHeight'] as num).toDouble(),
        );
      case 'OvalFit':
        return OvalFit(
          center: Offset(
              map['center'][0].toDouble(), map['center'][1].toDouble()),
          rx: (map['rx'] as num).toDouble(),
          ry: (map['ry'] as num).toDouble(),
        );
      case 'TriangleFit':
        return TriangleFit(
          a: Offset(map['a'][0].toDouble(), map['a'][1].toDouble()),
          b: Offset(map['b'][0].toDouble(), map['b'][1].toDouble()),
          c: Offset(map['c'][0].toDouble(), map['c'][1].toDouble()),
        );
      case 'StarFit':
        return StarFit(
          center: Offset(
              map['center'][0].toDouble(), map['center'][1].toDouble()),
          outerRadius: (map['outerRadius'] as num).toDouble(),
        );
      case 'NoneFit':
        return const NoneFit();
      default:
        return null;
    }
  }

  static List<Offset>? _decodeOriginalPoints(dynamic raw) {
    if (raw == null) return null;
    final list = raw as List;
    return [
      for (final item in list)
        Offset((item[0] as num).toDouble(), (item[1] as num).toDouble()),
    ];
  }

  static String encode(
    List<Stroke> strokes, {
    DoodleBackground background = DoodleBackground.dotted,
  }) {
    final data = <String, dynamic>{
      'version': _version,
      'background': background.name,
      'strokes': [
        for (final stroke in strokes)
          {
            'tool': stroke.tool.name,
            'color': stroke.color.toARGB32(),
            'width': stroke.width,
            'opacity': stroke.opacity,
            'isPerfectShape': stroke.isPerfectShape,
            if (stroke.shapeType != null) 'shapeType': stroke.shapeType!.name,
            if (stroke.recognitionConfidence != null)
              'recognitionConfidence': stroke.recognitionConfidence,
            if (stroke.originalPoints != null)
              'originalPoints': [
                for (final p in stroke.originalPoints!)
                  [p.dx, p.dy],
              ],
            if (stroke.isPerfectShape && stroke.fit != null)
              'fit': _encodeFit(stroke.fit),
            'points': [
              for (final point in stroke.points)
                [point.position.dx, point.position.dy, point.pressure],
            ],
          },
      ],
    };
    return jsonEncode(data);
  }

  static DoodleData decode(String source) {
    try {
      final data = jsonDecode(source) as Map<String, dynamic>;
      final strokes = <Stroke>[];

      for (final raw in (data['strokes'] as List? ?? [])) {
        final map = raw as Map<String, dynamic>;
        final points = <StrokePoint>[];
        for (final rawPoint in (map['points'] as List? ?? [])) {
          final list = (rawPoint as List).cast<num>();
          final dx = list[0].toDouble();
          final dy = list[1].toDouble();
          final pressure = list.length > 2 ? list[2].toDouble() : 1.0;
          points.add(StrokePoint(Offset(dx, dy), pressure: pressure));
        }

        // Support both v1 ('perfectShape') and v2/v3 ('isPerfectShape') field names.
        final perfectShape = map['isPerfectShape'] as bool? ??
            map['perfectShape'] as bool? ??
            false;

        // Deserialize shapeType if present (v2+).
        RecognizedShape? shapeType;
        final shapeName = map['shapeType'] as String?;
        if (shapeName != null) {
          shapeType = RecognizedShape.values.asNameMap()[shapeName];
        }

        final recognitionConfidence =
            map['recognitionConfidence'] as num?;

        final originalPoints = _decodeOriginalPoints(map['originalPoints']);

        final fit = _decodeFit(map['fit'] as Map<String, dynamic>?);

        strokes.add(
          Stroke(
            points: points,
            color: Color(map['color'] as int),
            width: (map['width'] as num).toDouble(),
            tool: DoodleTool.values.byName(map['tool'] as String),
            opacity: (map['opacity'] as num).toDouble(),
            isPerfectShape: perfectShape,
            shapeType: shapeType,
            recognitionConfidence: recognitionConfidence?.toDouble(),
            originalPoints: originalPoints,
            fit: fit,
          ),
        );
      }

      final background =
          DoodleBackground.values.asNameMap()[data['background']] ??
              DoodleBackground.dotted;

      return DoodleData(strokes: strokes, background: background);
    } catch (_) {
      return const DoodleData();
    }
  }
}
