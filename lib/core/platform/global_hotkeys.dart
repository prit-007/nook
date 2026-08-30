import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../../core/providers/talker_provider.dart';

/// Registers and manages global keyboard shortcuts for desktop platforms.
///
/// The primary binding is Ctrl+Shift+N (Cmd+Shift+N on macOS) which opens
/// the Quick Note overlay. This works even when the app is not focused,
/// allowing users to capture thoughts from any application.
///
/// Only active on desktop platforms (Linux, macOS, Windows). No-op on
/// mobile/web where system-wide hotkeys are not available.
class NookGlobalHotkeys {
  NookGlobalHotkeys._();

  static bool _initialized = false;

  /// Callback invoked when Ctrl+Shift+N is pressed.
  static VoidCallback? onQuickNote;

  /// Initializes global hotkeys. No-op on mobile/web.
  static Future<void> initialize({VoidCallback? onQuickNote}) async {
    if (_initialized) return;
    if (!kIsWeb &&
        !Platform.isLinux &&
        !Platform.isMacOS &&
        !Platform.isWindows) {
      return;
    }

    NookGlobalHotkeys.onQuickNote = onQuickNote;

    try {
      // Register Ctrl+Shift+N (Cmd+Shift+N on macOS) for Quick Note.
      final quickNoteHotKey = HotKey(
        key: LogicalKeyboardKey.keyN,
        modifiers: [
          HotKeyModifier.control,
          HotKeyModifier.shift,
        ],
        scope: HotKeyScope.inapp,
      );

      await HotKeyManager.instance.register(
        quickNoteHotKey,
        keyDownHandler: (hotKey) {
          nookLog(NookLogKey.editor, 'Global hotkey triggered: Quick Note',
              LogLevel.info);
          onQuickNote?.call();
        },
      );

      _initialized = true;
      nookLog(NookLogKey.security, 'Global hotkeys registered (Ctrl+Shift+N)',
          LogLevel.info);
    } catch (e) {
      nookLog(NookLogKey.security, 'Global hotkey init failed: $e',
          LogLevel.warning);
    }
  }

  /// Unregisters all hotkeys.
  static Future<void> dispose() async {
    if (!_initialized) return;
    try {
      await HotKeyManager.instance.unregisterAll();
    } catch (_) {
      // Best-effort.
    }
    _initialized = false;
  }
}
