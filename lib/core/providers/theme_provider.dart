import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/design_tokens.dart';

/// Persists: dynamic color on/off, manual seed index, dark/light/system mode.
class ThemePreference extends ChangeNotifier {
  ThemePreference({
    this.useDynamicColor = false,
    this.seedIndex = 0,
    this.themeMode = ThemeMode.system,
  });

  bool useDynamicColor;
  int seedIndex;
  ThemeMode themeMode;

  Color get seedColor => NookColors.seeds[seedIndex];

  void setDynamicColor(bool value) {
    useDynamicColor = value;
    notifyListeners();
    _save();
  }

  void setSeedIndex(int index) {
    seedIndex = index;
    notifyListeners();
    _save();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dynamic_color', useDynamicColor);
    await prefs.setInt('seed_index', seedIndex);
    await prefs.setInt('theme_mode', themeMode.index);
  }

  static Future<ThemePreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemePreference(
      useDynamicColor: prefs.getBool('dynamic_color') ?? false,
      seedIndex: prefs.getInt('seed_index') ?? 0,
      themeMode: ThemeMode.values[prefs.getInt('theme_mode') ?? 0],
    );
  }
}

final themePreferenceProvider = ChangeNotifierProvider<ThemePreference>((ref) {
  return ThemePreference(); // defaults until loaded
});

/// Provides the effective seed color, considering dynamic color preference.
final effectiveSeedColorProvider = Provider<Color>((ref) {
  final pref = ref.watch(themePreferenceProvider);
  // Dynamic color support will be added in Phase 3.
  // For now, always use the manual seed.
  return pref.seedColor;
});
