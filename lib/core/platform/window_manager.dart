import 'package:flutter/services.dart';

/// Lightweight replacement for the discontinued `flutter_windowmanager` package.
/// Uses a direct MethodChannel to add/clear WindowManager flags on Android.
class WindowManager {
  static const _channel = MethodChannel('com.nook/window_manager');

  /// WindowManager.LayoutParams.FLAG_SECURE
  static const int flagSecure = 0x00002000;

  static Future<void> addFlags(int flags) async {
    try {
      await _channel.invokeMethod<void>('addFlags', {'flags': flags});
    } on PlatformException {
      // Platform not supported (e.g. desktop, web) — silently ignore.
    } on MissingPluginException {
      // Platform not supported (e.g. desktop, web) — silently ignore.
    }
  }

  static Future<void> clearFlags(int flags) async {
    try {
      await _channel.invokeMethod<void>('clearFlags', {'flags': flags});
    } on PlatformException {
      // Platform not supported (e.g. desktop, web) — silently ignore.
    } on MissingPluginException {
      // Platform not supported (e.g. desktop, web) — silently ignore.
    }
  }
}
