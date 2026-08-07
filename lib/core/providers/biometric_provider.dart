import 'package:flutter/material.dart';

enum AppLockState { locked, unlocked }

/// Stub biometric gate provider.
/// Full implementation with local_auth in Phase 4.
class BiometricGate extends ChangeNotifier {
  AppLockState _state = AppLockState.unlocked;

  AppLockState get state => _state;

  void unlock() {
    _state = AppLockState.unlocked;
    notifyListeners();
  }

  void lock() {
    _state = AppLockState.locked;
    notifyListeners();
  }

  bool get isLocked => _state == AppLockState.locked;
}
