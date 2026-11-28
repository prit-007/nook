import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/tables/notes.dart';
import '../widgets/paper_texture_painter.dart';

/// Per-note-type default customization preset.
class NoteTypePreset {
  const NoteTypePreset({
    required this.type,
    required this.paperPattern,
    this.colorSeed,
    this.fontStyle,
  });

  final NoteType type;
  final PaperPattern paperPattern;
  final String? colorSeed;
  final String? fontStyle;

  factory NoteTypePreset.defaultFor(NoteType type) {
    return switch (type) {
      NoteType.text => const NoteTypePreset(
          type: NoteType.text,
          paperPattern: PaperPattern.ruled,
        ),
      NoteType.checklist => const NoteTypePreset(
          type: NoteType.checklist,
          paperPattern: PaperPattern.none,
        ),
      NoteType.doodle => const NoteTypePreset(
          type: NoteType.doodle,
          paperPattern: PaperPattern.dotted,
        ),
      NoteType.mixed => const NoteTypePreset(
          type: NoteType.mixed,
          paperPattern: PaperPattern.dotted,
        ),
    };
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'paperPattern': paperPattern.name,
        if (colorSeed != null) 'colorSeed': colorSeed,
        if (fontStyle != null) 'fontStyle': fontStyle,
      };

  factory NoteTypePreset.fromJson(Map<String, dynamic> json, NoteType type) {
    final patternName = json['paperPattern'] as String?;
    final pattern = PaperPattern.values.asNameMap()[patternName] ??
        NoteTypePreset.defaultFor(type).paperPattern;
    return NoteTypePreset(
      type: type,
      paperPattern: pattern,
      colorSeed: json['colorSeed'] as String?,
      fontStyle: json['fontStyle'] as String?,
    );
  }
}

/// Persists and notifies per-[NoteType] default presets.
class NoteTypePresetStore extends ChangeNotifier {
  NoteTypePresetStore([Map<NoteType, NoteTypePreset>? initial])
      : _presets = {
          for (final t in NoteType.values)
            t: initial?[t] ?? NoteTypePreset.defaultFor(t),
        };

  static const String _keyPrefix = 'note_type_preset_';
  final Map<NoteType, NoteTypePreset> _presets;

  NoteTypePreset forType(NoteType type) =>
      _presets[type] ?? NoteTypePreset.defaultFor(type);

  static Future<NoteTypePresetStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <NoteType, NoteTypePreset>{};
    for (final t in NoteType.values) {
      final raw = prefs.getString('$_keyPrefix${t.name}');
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          map[t] = NoteTypePreset.fromJson(decoded, t);
        } catch (_) {
          map[t] = NoteTypePreset.defaultFor(t);
        }
      }
    }
    return NoteTypePresetStore(map);
  }

  Future<void> updatePreset(NoteTypePreset preset) async {
    _presets[preset.type] = preset;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix${preset.type.name}',
      jsonEncode(preset.toJson()),
    );
  }
}

final noteTypePresetProvider = ChangeNotifierProvider<NoteTypePresetStore>(
  (ref) => NoteTypePresetStore(),
);
