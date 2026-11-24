import 'package:shared_preferences/shared_preferences.dart';

/// Persistable, customizable pen width presets for the doodle toolbar.
///
/// Presets are stored as a comma-separated list of strings under
/// 'nook_doodle_presets' in SharedPreferences. Defaults to [2, 5, 10, 16]
/// until [load] is called. The store is injectable for testing.
class DoodlePresetStore {
  static const List<double> _defaultPresets = [2.0, 5.0, 10.0, 16.0];
  static const int _maxPresets = 6;
  static const String _storageKey = 'nook_doodle_presets';

  final SharedPreferences _prefs;
  final List<double> _presets;

  DoodlePresetStore(this._prefs)
      : _presets = List<double>.from(_defaultPresets);

  /// Loads persisted presets from SharedPreferences, replacing defaults.
  /// Safe to call multiple times.
  Future<void> load() async {
    final strings = _prefs.getStringList(_storageKey);
    if (strings == null || strings.isEmpty) return;
    _presets
      ..clear()
      ..addAll(strings
          .map((s) => double.tryParse(s))
          .whereType<double>()
          .where((d) => d > 0));
  }

  /// Current list of preset stroke widths, in insertion order.
  List<double> get presets => List<double>.unmodifiable(_presets);

  /// Adds [width] to the presets if positive, not already present, and under
  /// the max preset count. Persists to SharedPreferences.
  void addPreset(double width) {
    if (width <= 0) return;
    if (_presets.any((p) => (p - width).abs() < 0.001)) return;
    if (_presets.length >= _maxPresets) return;
    _presets.add(width);
    _save();
  }

  /// Removes the first preset equal to [width] (within epsilon). Persists to
  /// SharedPreferences. No-op if not present.
  void removePreset(double width) {
    final index = _presets.indexWhere((p) => (p - width).abs() < 0.001);
    if (index == -1) return;
    _presets.removeAt(index);
    _save();
  }

  void _save() {
    _prefs.setStringList(
      _storageKey,
      _presets.map((p) => p.toString()).toList(),
    );
  }
}
