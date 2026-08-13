import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'talker_provider.dart';

enum AppLockState { locked, unlocked }

/// Auto-lock delay options.
enum AutoLockDuration {
  immediately,
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  never,
}

/// Injectable authenticator seam so the gate is testable without platform
/// channels. The default implementation wraps [LocalAuthentication].
typedef BiometricAuthenticator = Future<bool> Function();

/// App-level lock gate.
///
/// When `enabled`, the app locks on launch and whenever it returns from the
/// background; [unlock] runs the biometric prompt and animates the frosted
/// shield away on success.
class BiometricGate extends ChangeNotifier {
  BiometricGate({
    BiometricAuthenticator? authenticator,
    bool enabled = false,
    AutoLockDuration autoLockDuration = AutoLockDuration.fiveMinutes,
  })  : _authenticator = authenticator ?? _defaultAuthenticator,
        _enabled = enabled,
        _autoLockDuration = autoLockDuration;

  final BiometricAuthenticator _authenticator;

  bool _enabled;
  AppLockState _state = AppLockState.locked;
  bool _hasAuthenticated = false;
  bool _authenticating = false;
  AutoLockDuration _autoLockDuration;
  DateTime? _lastBackgroundedAt;

  /// Whether biometric locking is turned on (persisted).
  bool get enabled => _enabled;

  AppLockState get state => _state;

  bool get isLocked => _enabled && _state == AppLockState.locked;

  bool get isAuthenticating => _authenticating;

  AutoLockDuration get autoLockDuration => _autoLockDuration;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _save();
    if (value) {
      _lock();
    } else {
      _state = AppLockState.unlocked;
      _hasAuthenticated = false;
      _lastBackgroundedAt = null;
    }
    nookLog(NookLogKey.security,
        'Biometric lock ${value ? 'enabled' : 'disabled'}', LogLevel.info);
    notifyListeners();
  }

  /// Enables the lock only after the platform can complete an authentication.
  /// This prevents Windows machines without Windows Hello from trapping users
  /// behind a lock they cannot satisfy.
  Future<bool> enableWithVerification() async {
    if (_enabled) return true;
    final ok = await _authenticator();
    if (!ok) return false;
    _enabled = true;
    _state = AppLockState.unlocked;
    _hasAuthenticated = true;
    await _save();
    notifyListeners();
    return true;
  }

  void setAutoLockDuration(AutoLockDuration value) {
    _autoLockDuration = value;
    nookLog(
      NookLogKey.security,
      'Auto-lock duration set to ${value.name}',
      LogLevel.info,
    );
    notifyListeners();
    _save();
  }

  void _lock() {
    _state = AppLockState.locked;
    _hasAuthenticated = false;
    notifyListeners();
  }

  /// Locks the app now (e.g. lifecycle pause/resume while enabled).
  void lock() {
    if (!_enabled) return;
    _lock();
  }

  /// Attempts to unlock via the biometric prompt. Returns success.
  Future<bool> unlock() async {
    if (!_enabled) {
      _state = AppLockState.unlocked;
      notifyListeners();
      return true;
    }
    if (!_hasAuthenticated) {
      if (_authenticating) return false;
      _authenticating = true;
      notifyListeners();
      bool ok = false;
      try {
        ok = await _authenticator();
      } catch (_) {
        ok = false;
      } finally {
        _authenticating = false;
      }
      if (!ok) {
        nookLog(NookLogKey.security, 'Biometric authentication failed',
            LogLevel.warning);
        return false;
      }
      nookLog(NookLogKey.security, 'Biometric authentication succeeded',
          LogLevel.info);
      _hasAuthenticated = true;
    }
    _state = AppLockState.unlocked;
    _lastBackgroundedAt = null;
    notifyListeners();
    return true;
  }

  /// Unlocks via PIN fallback — no biometric prompt needed.
  void unlockWithPin() {
    _hasAuthenticated = true;
    _state = AppLockState.unlocked;
    _lastBackgroundedAt = null;
    notifyListeners();
  }

  /// Called on app lifecycle pause — records when we went to background.
  void onAppPaused() {
    if (_enabled && _hasAuthenticated) {
      _lastBackgroundedAt = DateTime.now();
    }
  }

  /// Called on app lifecycle resume: relocks if enabled and the auto-lock
  /// timer has elapsed. If [onAppPaused] was never called, relocks
  /// immediately (conservative default).
  void onAppResumed() {
    if (!_enabled || !_hasAuthenticated || _authenticating) return;

    if (_autoLockDuration == AutoLockDuration.never) return;

    if (_autoLockDuration == AutoLockDuration.immediately) {
      _lock();
      return;
    }

    if (_lastBackgroundedAt != null) {
      final elapsed = DateTime.now().difference(_lastBackgroundedAt!);
      final threshold = _autoLockDuration.duration;
      if (elapsed >= threshold) {
        _lock();
      }
    } else {
      _lock();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', _enabled);
    await prefs.setInt('auto_lock_duration', _autoLockDuration.index);
  }

  static Future<BiometricGate> load() async {
    final prefs = await SharedPreferences.getInstance();
    final durationIndex = prefs.getInt('auto_lock_duration') ?? 2;
    return BiometricGate(
      enabled: prefs.getBool('biometric_enabled') ?? false,
      autoLockDuration: AutoLockDuration
          .values[durationIndex.clamp(0, AutoLockDuration.values.length - 1)],
    );
  }
}

extension _AutoLockDurationExt on AutoLockDuration {
  Duration get duration => switch (this) {
        AutoLockDuration.immediately => Duration.zero,
        AutoLockDuration.oneMinute => const Duration(minutes: 1),
        AutoLockDuration.fiveMinutes => const Duration(minutes: 5),
        AutoLockDuration.fifteenMinutes => const Duration(minutes: 15),
        AutoLockDuration.never => const Duration(days: 365),
      };
}

Future<bool> _defaultAuthenticator() {
  final auth = LocalAuthentication();
  final isWindows = defaultTargetPlatform == TargetPlatform.windows;
  return () async {
    try {
      if (!await auth.isDeviceSupported()) return false;
      if (!isWindows && (await auth.getAvailableBiometrics()).isEmpty) {
        return false;
      }
      return auth.authenticate(
        localizedReason: isWindows
            ? 'Use Windows Hello to unlock your vault'
            : 'Unlock your vault',
        // Windows Hello may be configured with a PIN, so biometricOnly would
        // incorrectly reject a valid Windows Hello credential.
        biometricOnly: !isWindows,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }();
}

final biometricGateProvider = ChangeNotifierProvider<BiometricGate>((ref) {
  return BiometricGate(); // defaults until enabled via settings
});
