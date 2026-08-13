import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/design_tokens.dart';

/// Persists: manual seed index, dark/light/system mode, reduce-motion flag,
/// and AMOLED true-black dark-mode flag.
class ThemePreference extends ChangeNotifier {
  ThemePreference({
    this.seedIndex = 0,
    this.themeMode = ThemeMode.system,
    this.reduceMotion = false,
    this.amoledDark = false,
  });

  int seedIndex;
  ThemeMode themeMode;
  bool reduceMotion;
  bool amoledDark;

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

  void setReduceMotion(bool value) {
    reduceMotion = value;
    notifyListeners();
    _save();
  }

  void setAmoledDark(bool value) {
    amoledDark = value;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seed_index', seedIndex);
    await prefs.setInt('theme_mode', themeMode.index);
    await prefs.setBool('reduce_motion', reduceMotion);
    await prefs.setBool('amoled_dark', amoledDark);
  }

  static Future<ThemePreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('theme_mode') ?? 0;
    return ThemePreference(
      seedIndex: prefs.getInt('seed_index') ?? 0,
      themeMode:
          ThemeMode.values[modeIndex.clamp(0, ThemeMode.values.length - 1)],
      reduceMotion: prefs.getBool('reduce_motion') ?? false,
      amoledDark: prefs.getBool('amoled_dark') ?? false,
    );
  }
}

/// Initializes ThemePreference from disk once, then stays in sync.
final themePreferenceProvider = ChangeNotifierProvider<ThemePreference>((ref) {
  // Will be overridden at startup via ProviderScope with loaded value.
  return ThemePreference();
});
