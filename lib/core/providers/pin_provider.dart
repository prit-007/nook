import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/kdf.dart';
import 'talker_provider.dart';

/// Manages PIN code for app-level lock fallback.
///
/// The PIN is hashed with a random salt and stored in the platform keystore
/// via `flutter_secure_storage`. The raw PIN is never persisted.
///
/// Hashing is delegated to [lib/core/security/kdf.dart] so vault password and
/// other secrets share one audited PBKDF2 implementation.
class PinProvider extends ChangeNotifier {
  PinProvider({
    this.enabled = false,
    int failedAttempts = 0,
    DateTime? lockoutUntil,
  })  : _failedAttempts = failedAttempts,
        _lockoutUntil = lockoutUntil;

  static const String _failedAttemptsKey = 'pin_failed_attempts';
  static const String _lockoutUntilKey = 'pin_lockout_until_ms';

  bool enabled;
  bool _authenticated = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

  bool get isAuthenticated => _authenticated;
  int get failedAttempts => _failedAttempts;
  DateTime? get lockoutUntil => _lockoutUntil;

  /// Whether the user is currently locked out from entering PIN.
  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  /// Remaining seconds in the current lockout window.
  int get remainingLockoutSeconds {
    if (!isLockedOut) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds.clamp(0, 86400);
  }

  /// Records a failed PIN entry and applies exponential lockout thresholds.
  void recordFailedAttempt() {
    _failedAttempts++;
    if (_failedAttempts >= 7) {
      _lockoutUntil = DateTime.now().add(const Duration(seconds: 300));
    } else if (_failedAttempts >= 5) {
      _lockoutUntil = DateTime.now().add(const Duration(seconds: 60));
    } else if (_failedAttempts >= 3) {
      _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
    }
    notifyListeners();
  }

  /// Records a failed PIN entry and persists the lockout state across restarts.
  Future<void> recordFailedAttemptPersisted() async {
    recordFailedAttempt();
    await _saveLockoutState();
  }

  /// Resets failed attempt counter and clears active lockout.
  void resetAttempts() {
    _failedAttempts = 0;
    _lockoutUntil = null;
    notifyListeners();
  }

  /// Verifies [pin] against the stored hash. Returns true on match.
  Future<bool> verify(String pin) async {
    if (isLockedOut) return false;

    final stored = await _readHash();
    if (stored == null) return false;
    final match = pbkdf2Verify(password: pin, storedHash: stored);
    if (match) {
      _authenticated = true;
      _failedAttempts = 0;
      _lockoutUntil = null;
      await _saveLockoutState();
      nookLog(NookLogKey.security, 'PIN verified', LogLevel.info);
      notifyListeners();
    } else {
      await recordFailedAttemptPersisted();
      nookLog(NookLogKey.security, 'PIN verification failed', LogLevel.warning);
    }
    return match;
  }

  /// Sets a new PIN (hashed with fresh salt). Enables PIN lock.
  Future<void> setPin(String pin) async {
    final hash = pbkdf2Hash(password: pin);
    await _writeHash(hash);
    enabled = true;
    nookLog(NookLogKey.security, 'PIN set', LogLevel.info);
    notifyListeners();
    await _save();
  }

  /// Clears the stored PIN and disables PIN lock.
  Future<void> clearPin() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'pin_hash');
    enabled = false;
    _authenticated = false;
    notifyListeners();
    await _save();
  }

  /// Called when the app locks — reset authentication state.
  void resetAuth() {
    _authenticated = false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pin_enabled', enabled);
  }

  Future<void> _saveLockoutState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_failedAttemptsKey, _failedAttempts);
    if (_lockoutUntil != null) {
      await prefs.setInt(
        _lockoutUntilKey,
        _lockoutUntil!.millisecondsSinceEpoch,
      );
    } else {
      await prefs.remove(_lockoutUntilKey);
    }
  }

  static Future<PinProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('pin_enabled') ?? false;
    final attempts = prefs.getInt(_failedAttemptsKey) ?? 0;
    final lockoutMs = prefs.getInt(_lockoutUntilKey);
    return PinProvider(
      enabled: isEnabled,
      failedAttempts: attempts,
      lockoutUntil: lockoutMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lockoutMs)
          : null,
    );
  }

  // ── Storage helpers ─────────────────────────────────────────────

  Future<String?> _readHash() async {
    const storage = FlutterSecureStorage();
    final hash = await storage.read(key: 'pin_hash');
    return hash;
  }

  Future<void> _writeHash(String hash) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'pin_hash', value: hash);
  }
}

final pinProvider = ChangeNotifierProvider<PinProvider>((ref) {
  return PinProvider(); // defaults until loaded
});
