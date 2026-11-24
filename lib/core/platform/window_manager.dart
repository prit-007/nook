import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight replacement for the discontinued `flutter_windowmanager` package,
/// providing Android window flag management (`FLAG_SECURE`) as well as desktop
/// window bounds (size & position) persistence with debounced disk I/O.
class WindowManager {
  static const _channel = MethodChannel('com.nook/window_manager');

  /// WindowManager.LayoutParams.FLAG_SECURE (Android)
  static const int flagSecure = 0x00002000;

  // ---------------------------------------------------------------------------
  // Android Window Flags (FLAG_SECURE)
  // ---------------------------------------------------------------------------

  /// Adds the given window flags on Android (e.g. [flagSecure] for screenshot blocking).
  /// Safely ignored on non-Android platforms.
  static Future<void> addFlags(int flags) async {
    try {
      await _channel.invokeMethod<void>('addFlags', {'flags': flags});
    } on PlatformException {
      // Platform not supported (e.g. desktop, web) — silently ignore.
    } on MissingPluginException {
      // Platform not supported (e.g. desktop, web) — silently ignore.
    }
  }

  /// Clears the given window flags on Android.
  /// Safely ignored on non-Android platforms.
  static Future<void> clearFlags(int flags) async {
    try {
      await _channel.invokeMethod<void>('clearFlags', {'flags': flags});
    } on PlatformException {
      // Platform not supported (e.g. desktop, web) — silently ignore.
    } on MissingPluginException {
      // Platform not supported (e.g. desktop, web) — silently ignore.
    }
  }

  // ---------------------------------------------------------------------------
  // Desktop Window Size & Position Persistence (Task 6.2)
  // ---------------------------------------------------------------------------

  /// SharedPreferences key for window width in logical pixels.
  static const String keyWindowWidth = 'window_width';

  /// SharedPreferences key for window height in logical pixels.
  static const String keyWindowHeight = 'window_height';

  /// SharedPreferences key for window X offset in logical pixels.
  static const String keyWindowX = 'window_x';

  /// SharedPreferences key for window Y offset in logical pixels.
  static const String keyWindowY = 'window_y';

  /// Default window size when no dimensions have been persisted (1200x800).
  static const Size defaultWindowSize = Size(1200.0, 800.0);

  /// Default debounce duration when saving size or position during continuous
  /// window resize or move operations (300 ms).
  static const Duration defaultDebounceDuration = Duration(milliseconds: 300);

  // Internal debounce state for window size
  static Timer? _sizeDebounceTimer;
  static Size? _pendingSize;
  static Completer<void>? _sizeCompleter;

  // Internal debounce state for window position
  static Timer? _positionDebounceTimer;
  static Offset? _pendingPosition;
  static Completer<void>? _positionCompleter;

  /// Whether a debounced window size save is currently pending.
  static bool get hasPendingSizeSave => _sizeDebounceTimer?.isActive ?? false;

  /// Whether a debounced window position save is currently pending.
  static bool get hasPendingPositionSave =>
      _positionDebounceTimer?.isActive ?? false;

  /// Saves the window size to [SharedPreferences].
  ///
  /// If [debounceDuration] is provided and greater than [Duration.zero], the
  /// save operation is debounced. Any pending save timer is cancelled and
  /// rescheduled with the new [size], returning a [Future] that completes once
  /// the size is persisted to disk.
  ///
  /// If [debounceDuration] is omitted or zero, any active debounce timer is
  /// cancelled and the [size] is written to disk immediately.
  static Future<void> saveWindowSize(
    Size size, {
    Duration? debounceDuration,
  }) async {
    if (debounceDuration != null && debounceDuration > Duration.zero) {
      _sizeDebounceTimer?.cancel();
      _pendingSize = size;
      if (_sizeCompleter == null || _sizeCompleter!.isCompleted) {
        _sizeCompleter = Completer<void>();
      }
      _sizeDebounceTimer = Timer(debounceDuration, () async {
        final toSave = _pendingSize;
        _pendingSize = null;
        if (toSave != null) {
          await _persistSize(toSave);
        }
        if (_sizeCompleter != null && !_sizeCompleter!.isCompleted) {
          _sizeCompleter!.complete();
        }
      });
      return _sizeCompleter!.future;
    }

    _sizeDebounceTimer?.cancel();
    _pendingSize = null;
    await _persistSize(size);
    if (_sizeCompleter != null && !_sizeCompleter!.isCompleted) {
      _sizeCompleter!.complete();
    }
  }

  /// Convenience helper to save window size with debouncing (defaults to [defaultDebounceDuration]).
  ///
  /// Useful in window resize listener callbacks to prevent I/O thrashing during continuous drags.
  static void saveWindowSizeDebounced(
    Size size, {
    Duration debounceDuration = defaultDebounceDuration,
  }) {
    unawaited(saveWindowSize(size, debounceDuration: debounceDuration));
  }

  /// Loads the persisted window size from [SharedPreferences].
  ///
  /// Returns [defaultSize] (1200x800 by default) if no size has been persisted,
  /// or if the persisted values are non-positive or corrupted.
  static Future<Size> loadWindowSize({
    Size defaultSize = defaultWindowSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final width = _getDouble(prefs, keyWindowWidth);
    final height = _getDouble(prefs, keyWindowHeight);
    if (width != null && height != null && width > 0 && height > 0) {
      return Size(width, height);
    }
    return defaultSize;
  }

  /// Saves the window position to [SharedPreferences].
  ///
  /// If [debounceDuration] is provided and greater than [Duration.zero], the
  /// save operation is debounced. Any pending save timer is cancelled and
  /// rescheduled with the new [position], returning a [Future] that completes once
  /// the position is persisted to disk.
  ///
  /// If [debounceDuration] is omitted or zero, any active debounce timer is
  /// cancelled and the [position] is written to disk immediately.
  static Future<void> saveWindowPosition(
    Offset position, {
    Duration? debounceDuration,
  }) async {
    if (debounceDuration != null && debounceDuration > Duration.zero) {
      _positionDebounceTimer?.cancel();
      _pendingPosition = position;
      if (_positionCompleter == null || _positionCompleter!.isCompleted) {
        _positionCompleter = Completer<void>();
      }
      _positionDebounceTimer = Timer(debounceDuration, () async {
        final toSave = _pendingPosition;
        _pendingPosition = null;
        if (toSave != null) {
          await _persistPosition(toSave);
        }
        if (_positionCompleter != null && !_positionCompleter!.isCompleted) {
          _positionCompleter!.complete();
        }
      });
      return _positionCompleter!.future;
    }

    _positionDebounceTimer?.cancel();
    _pendingPosition = null;
    await _persistPosition(position);
    if (_positionCompleter != null && !_positionCompleter!.isCompleted) {
      _positionCompleter!.complete();
    }
  }

  /// Convenience helper to save window position with debouncing (defaults to [defaultDebounceDuration]).
  ///
  /// Useful in window move listener callbacks to prevent I/O thrashing during continuous moves.
  static void saveWindowPositionDebounced(
    Offset position, {
    Duration debounceDuration = defaultDebounceDuration,
  }) {
    unawaited(saveWindowPosition(position, debounceDuration: debounceDuration));
  }

  /// Loads the persisted window position from [SharedPreferences].
  ///
  /// Returns [defaultPosition] (defaults to `null`) if no position has been persisted
  /// or if either coordinate is missing.
  static Future<Offset?> loadWindowPosition({
    Offset? defaultPosition,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final x = _getDouble(prefs, keyWindowX);
    final y = _getDouble(prefs, keyWindowY);
    if (x != null && y != null) {
      return Offset(x, y);
    }
    return defaultPosition;
  }

  /// Immediately flushes any pending debounced size and position saves to disk.
  static Future<void> flushPendingSaves() async {
    if (_sizeDebounceTimer?.isActive ?? false) {
      _sizeDebounceTimer?.cancel();
      final toSave = _pendingSize;
      _pendingSize = null;
      if (toSave != null) {
        await _persistSize(toSave);
      }
      if (_sizeCompleter != null && !_sizeCompleter!.isCompleted) {
        _sizeCompleter!.complete();
      }
    }

    if (_positionDebounceTimer?.isActive ?? false) {
      _positionDebounceTimer?.cancel();
      final toSave = _pendingPosition;
      _pendingPosition = null;
      if (toSave != null) {
        await _persistPosition(toSave);
      }
      if (_positionCompleter != null && !_positionCompleter!.isCompleted) {
        _positionCompleter!.complete();
      }
    }
  }

  /// Cancels any scheduled debounced saves without writing them to disk.
  static void cancelPendingSaves() {
    _sizeDebounceTimer?.cancel();
    _sizeDebounceTimer = null;
    _pendingSize = null;
    if (_sizeCompleter != null && !_sizeCompleter!.isCompleted) {
      _sizeCompleter!.complete();
    }

    _positionDebounceTimer?.cancel();
    _positionDebounceTimer = null;
    _pendingPosition = null;
    if (_positionCompleter != null && !_positionCompleter!.isCompleted) {
      _positionCompleter!.complete();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  static Future<void> _persistSize(Size size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyWindowWidth, size.width);
    await prefs.setDouble(keyWindowHeight, size.height);
  }

  static Future<void> _persistPosition(Offset position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyWindowX, position.dx);
    await prefs.setDouble(keyWindowY, position.dy);
  }

  static double? _getDouble(SharedPreferences prefs, String key) {
    try {
      return prefs.getDouble(key);
    } catch (_) {
      final val = prefs.get(key);
      if (val is num) return val.toDouble();
      return null;
    }
  }
}
