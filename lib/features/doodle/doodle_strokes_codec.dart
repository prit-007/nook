import 'dart:convert';

import 'package:flutter/painting.dart';

import 'doodle_controller.dart';
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

  static const int _version = 2;

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

        // Support both v1 ('perfectShape') and v2 ('isPerfectShape') field names.
        final perfectShape = map['isPerfectShape'] as bool? ??
            map['perfectShape'] as bool? ??
            false;

        // Deserialize shapeType if present (v2+).
        RecognizedShape? shapeType;
        final shapeName = map['shapeType'] as String?;
        if (shapeName != null) {
          shapeType = RecognizedShape.values.asNameMap()[shapeName];
        }

        strokes.add(
          Stroke(
            points: points,
            color: Color(map['color'] as int),
            width: (map['width'] as num).toDouble(),
            tool: DoodleTool.values.byName(map['tool'] as String),
            opacity: (map['opacity'] as num).toDouble(),
            isPerfectShape: perfectShape,
            shapeType: shapeType,
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
