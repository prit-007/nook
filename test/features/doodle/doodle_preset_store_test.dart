import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nook/features/doodle/doodle_preset_store.dart';

void main() {
  group('DoodlePresetStore', () {
    test('defaults to [2, 5, 10, 16] when no stored presets', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DoodlePresetStore(prefs);
      expect(store.presets, equals([2.0, 5.0, 10.0, 16.0]));
    });

    test('loads stored presets from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'nook_doodle_presets': ['3.0', '7.0', '12.0'],
      });
      final prefs = await SharedPreferences.getInstance();
      final store = DoodlePresetStore(prefs);
      await store.load();
      expect(store.presets, equals([3.0, 7.0, 12.0]));
    });

    test('addPreset appends and deduplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DoodlePresetStore(prefs);
      await store.load();

      store.addPreset(7.5);
      expect(store.presets, equals([2.0, 5.0, 10.0, 16.0, 7.5]));

      store.addPreset(5.0); // duplicate, should be ignored
      expect(store.presets, equals([2.0, 5.0, 10.0, 16.0, 7.5]));
    });

    test('addPreset enforces max 6 presets', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DoodlePresetStore(prefs);
      await store.load();

      store.addPreset(1.0);
      store.addPreset(2.5);
      store.addPreset(3.5);
      store.addPreset(4.5);
      expect(store.presets.length, equals(6));

      store.addPreset(5.5); // would be 7th, should be rejected
      expect(store.presets.length, equals(6));
    });

    test('removePreset removes matching value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DoodlePresetStore(prefs);
      await store.load();

      store.removePreset(5.0);
      expect(store.presets, equals([2.0, 10.0, 16.0]));

      store.removePreset(99.0); // non-existent, no-op
      expect(store.presets, equals([2.0, 10.0, 16.0]));
    });

    test('persists changes to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DoodlePresetStore(prefs);
      await store.load();

      store.addPreset(7.5);
      expect(prefs.getStringList('nook_doodle_presets'),
          equals(['2.0', '5.0', '10.0', '16.0', '7.5']));

      // New store instance should load the persisted value
      final store2 = DoodlePresetStore(prefs);
      await store2.load();
      expect(store2.presets, equals([2.0, 5.0, 10.0, 16.0, 7.5]));
    });

    test('rejects non-positive widths', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = DoodlePresetStore(prefs);
      await store.load();

      store.addPreset(0.0);
      store.addPreset(-1.0);
      expect(store.presets, equals([2.0, 5.0, 10.0, 16.0]));
    });
  });
}
