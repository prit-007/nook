import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';

import '../../core/providers/talker_provider.dart';

/// Manages the system tray icon and menu for desktop platforms.
///
/// Shows a tray icon with a context menu containing:
/// - Quick Note (opens the quick-capture overlay)
/// - Show/Hide window
/// - Quit
///
/// Only active on desktop platforms (Linux, macOS, Windows).
class NookSystemTray {
  NookSystemTray._();

  static SystemTray? _tray;
  static bool _initialized = false;

  /// Callback invoked when the user selects "Quick Note" from the tray menu.
  static VoidCallback? onQuickNote;

  /// Callback invoked when the user selects "Show" from the tray menu.
  static VoidCallback? onShowWindow;

  /// Initializes the system tray. No-op on mobile/web.
  static Future<void> initialize({
    VoidCallback? onQuickNote,
    VoidCallback? onShowWindow,
  }) async {
    if (_initialized) return;
    if (!kIsWeb &&
        !Platform.isLinux &&
        !Platform.isMacOS &&
        !Platform.isWindows) {
      return;
    }

    NookSystemTray.onQuickNote = onQuickNote;
    NookSystemTray.onShowWindow = onShowWindow;

    try {
      _tray = SystemTray();

      await _tray!.initSystemTray(
        title: 'nook.',
        iconPath: 'assets/icons/favicon_full.png',
        toolTip: 'nook. — Quick Note',
      );

      // Build the context menu.
      await _tray!.setContextMenu([
        MenuItem(
          label: 'Quick Note',
          onClicked: () {
            nookLog(NookLogKey.security, 'Tray: Quick Note requested',
                LogLevel.info);
            onQuickNote?.call();
          },
        ),
        MenuSeparator(),
        MenuItem(
          label: 'Show nook.',
          onClicked: () {
            nookLog(NookLogKey.security, 'Tray: Show window requested',
                LogLevel.info);
            onShowWindow?.call();
          },
        ),
        MenuSeparator(),
        MenuItem(
          label: 'Quit',
          onClicked: () {
            nookLog(NookLogKey.security, 'Tray: Quit requested', LogLevel.info);
            exit(0);
          },
        ),
      ]);

      // Handle tray icon click (show window).
      _tray!.registerSystemTrayEventHandler((event) {
        if (event == 'click' || event == 'doubleClick') {
          onShowWindow?.call();
        }
      });

      _initialized = true;
      nookLog(NookLogKey.security, 'System tray initialized', LogLevel.info);
    } catch (e) {
      nookLog(
          NookLogKey.security, 'System tray init failed: $e', LogLevel.warning);
    }
  }

  /// Updates the tray tooltip (e.g. to show note count).
  static Future<void> updateToolTip(String tooltip) async {
    try {
      await _tray?.setTitle(tooltip);
    } catch (_) {
      // Best-effort.
    }
  }

  /// Disposes the system tray.
  static void dispose() {
    _tray = null;
    _initialized = false;
  }
}
