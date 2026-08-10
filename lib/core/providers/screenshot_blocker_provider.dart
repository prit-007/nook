import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:nook/core/platform/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls system-level screenshot/screen-recording blocking.
class ScreenshotBlocker extends ChangeNotifier {
  ScreenshotBlocker({this.blocked = false});

  bool blocked;

  /// Re-applies the platform FLAG_SECURE without checking the guard clause.
  /// Used at startup to restore the persisted state.
  Future<void> applyPersisted() async {
    await _apply();
  }

  Future<void> setBlocked(bool value) async {
    if (blocked == value) return;
    blocked = value;
    notifyListeners();
    await _apply();
    await _save();
  }

  Future<void> _apply() async {
    if (kIsWeb) return;
    try {
      if (blocked) {
        await WindowManager.addFlags(
          WindowManager.flagSecure,
        );
      } else {
        await WindowManager.clearFlags(
          WindowManager.flagSecure,
        );
      }
    } catch (_) {
      // Platform not supported (e.g. desktop, web) — silently ignore.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('screenshot_blocked', blocked);
  }

  static Future<ScreenshotBlocker> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ScreenshotBlocker(
      blocked: prefs.getBool('screenshot_blocked') ?? false,
    );
  }
}

final screenshotBlockerProvider =
    ChangeNotifierProvider<ScreenshotBlocker>((ref) {
  return ScreenshotBlocker(); // defaults until loaded
});
