import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/note_type_preset_provider.dart';
import 'package:nook/core/widgets/paper_texture_painter.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NoteTypePresetStore', () {
    test('provides sensible defaults and persists custom per-type presets',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = await NoteTypePresetStore.load();

      expect(store.forType(NoteType.text).paperPattern, PaperPattern.ruled);
      expect(store.forType(NoteType.checklist).paperPattern, PaperPattern.none);
      expect(store.forType(NoteType.doodle).paperPattern, PaperPattern.dotted);

      await store.updatePreset(
        const NoteTypePreset(
          type: NoteType.text,
          paperPattern: PaperPattern.graph,
          colorSeed: '#6750A4',
          fontStyle: 'serif',
        ),
      );

      final reloaded = await NoteTypePresetStore.load();
      final textPreset = reloaded.forType(NoteType.text);
      expect(textPreset.paperPattern, PaperPattern.graph);
      expect(textPreset.colorSeed, '#6750A4');
      expect(textPreset.fontStyle, 'serif');
    });
  });
}
