import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLockState { locked, unlocked }

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
  })  : _authenticator = authenticator ?? _defaultAuthenticator,
        _enabled = enabled;

  final BiometricAuthenticator _authenticator;

  bool _enabled;
  AppLockState _state = AppLockState.locked;
  bool _hasAuthenticated = false;
  bool _authenticating = false;

  /// Whether biometric locking is turned on (persisted).
  bool get enabled => _enabled;

  AppLockState get state => _state;

  bool get isLocked => _enabled && _state == AppLockState.locked;

  bool get isAuthenticating => _authenticating;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    _save();
    if (value) {
      _lock();
    } else {
      unlock();
    }
  }

  Future<void> _lock() async {
    _state = AppLockState.locked;
    _hasAuthenticated = false;
    notifyListeners();
  }

  /// Locks the app now (e.g. lifecycle pause/resume while enabled).
  Future<void> lock() async {
    if (!_enabled) return;
    await _lock();
  }

  /// Attempts to unlock via the biometric prompt. Returns success.
  Future<bool> unlock() async {
    if (!_enabled) return true;
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
      if (!ok) return false;
      _hasAuthenticated = true;
    }
    _state = AppLockState.unlocked;
    notifyListeners();
    return true;
  }

  /// Called on app lifecycle resume: relocks if enabled and previously
  /// authenticated, unless the shield is mid-unlock.
  Future<void> onAppResumed() async {
    if (_enabled && _hasAuthenticated && !_authenticating) {
      await _lock();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', _enabled);
  }

  static Future<BiometricGate> load() async {
    final prefs = await SharedPreferences.getInstance();
    return BiometricGate(
      enabled: prefs.getBool('biometric_enabled') ?? false,
    );
  }
}

Future<bool> _defaultAuthenticator() {
  final auth = LocalAuthentication();
  return auth.authenticate(
    localizedReason: 'Unlock your vault',
    biometricOnly: true,
    persistAcrossBackgrounding: true,
  );
}

final biometricGateProvider = ChangeNotifierProvider<BiometricGate>((ref) {
  return BiometricGate(); // defaults until enabled via settings
});
