import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/providers/talker_provider.dart';

/// Manages the system tray icon and menu for desktop platforms.
///
/// Currently a no-op placeholder — the system_tray package requires
/// platform-specific system libraries (appindicator3 on Linux) that
/// aren't available in all build environments. The tray icon and
/// Quick Note menu can be re-enabled when those dependencies are
/// guaranteed to be present.
///
/// The in-app Quick Note overlay (Ctrl+Shift+N) still works.
class NookSystemTray {
  NookSystemTray._();

  static bool _initialized = false;

  /// Callback invoked when the user selects "Quick Note" from the tray menu.
  static VoidCallback? onQuickNote;

  /// Callback invoked when the user selects "Show" from the tray menu.
  static VoidCallback? onShowWindow;

  /// Initializes the system tray. Currently a no-op.
  static Future<void> initialize({
    VoidCallback? onQuickNote,
    VoidCallback? onShowWindow,
  }) async {
    if (_initialized) return;

    NookSystemTray.onQuickNote = onQuickNote;
    NookSystemTray.onShowWindow = onShowWindow;
    _initialized = true;

    nookLog(
      NookLogKey.security,
      'System tray placeholder registered '
      '(requires appindicator3 on Linux)',
      LogLevel.info,
    );
  }

  /// Updates the tray tooltip. No-op.
  static Future<void> updateToolTip(String tooltip) async {}

  /// Disposes the system tray. No-op.
  static void dispose() {
    _initialized = false;
  }
}
