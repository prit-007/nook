import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls system-level screenshot/screen-recording blocking.
class ScreenshotBlocker extends ChangeNotifier {
  ScreenshotBlocker({this.blocked = false});

  bool blocked;

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
        await FlutterWindowManager.addFlags(
          FlutterWindowManager.FLAG_SECURE,
        );
      } else {
        await FlutterWindowManager.clearFlags(
          FlutterWindowManager.FLAG_SECURE,
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
