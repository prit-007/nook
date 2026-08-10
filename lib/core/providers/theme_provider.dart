import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/design_tokens.dart';

/// Persists: manual seed index, dark/light/system mode.
class ThemePreference extends ChangeNotifier {
  ThemePreference({
    this.seedIndex = 0,
    this.themeMode = ThemeMode.system,
  });

  int seedIndex;
  ThemeMode themeMode;

  Color get seedColor => NookColors.seeds[seedIndex];

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
    await prefs.setInt('seed_index', seedIndex);
    await prefs.setInt('theme_mode', themeMode.index);
  }

  static Future<ThemePreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('theme_mode') ?? 0;
    return ThemePreference(
      seedIndex: prefs.getInt('seed_index') ?? 0,
      themeMode:
          ThemeMode.values[modeIndex.clamp(0, ThemeMode.values.length - 1)],
    );
  }
}

/// Initializes ThemePreference from disk once, then stays in sync.
final themePreferenceProvider = ChangeNotifierProvider<ThemePreference>((ref) {
  // Will be overridden at startup via ProviderScope with loaded value.
  return ThemePreference();
});
