import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/providers/talker_provider.dart';

/// Registers and manages global keyboard shortcuts for desktop platforms.
///
/// Currently a placeholder — the primary shortcut (Ctrl+Shift+N) works
/// in-app via `NookKeyboardShortcuts`. Global hotkeys (when the app is
/// unfocused) require system-level dependencies that aren't available on
/// all Linux builds. This can be re-enabled when `keybinder-3.0` is
/// guaranteed to be present.
///
/// See: https://github.com/leanflutter/hotkey_manager#linux-requirements
class NookGlobalHotkeys {
  NookGlobalHotkeys._();

  static bool _initialized = false;

  /// Callback invoked when Ctrl+Shift+N is pressed.
  static VoidCallback? onQuickNote;

  /// Initializes global hotkeys. No-op on mobile/web and currently
  /// a no-op on desktop until system dependencies are guaranteed.
  static Future<void> initialize({VoidCallback? onQuickNote}) async {
    if (_initialized) return;
    if (!kIsWeb &&
        !Platform.isLinux &&
        !Platform.isMacOS &&
        !Platform.isWindows) {
      return;
    }

    NookGlobalHotkeys.onQuickNote = onQuickNote;
    _initialized = true;

    nookLog(
      NookLogKey.security,
      'Global hotkeys placeholder registered '
      '(Ctrl+Shift+N via in-app shortcuts)',
      LogLevel.info,
    );
  }

  /// Unregisters all hotkeys.
  static Future<void> dispose() async {
    _initialized = false;
  }
}
