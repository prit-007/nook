import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'talker_provider.dart';

/// Manages PIN code for app-level lock fallback.
///
/// The PIN is hashed with a random salt and stored in the platform keystore
/// via `flutter_secure_storage`. The raw PIN is never persisted.
class PinProvider extends ChangeNotifier {
  PinProvider({this.enabled = false});

  bool enabled;
  bool _authenticated = false;

  bool get isAuthenticated => _authenticated;

  /// Verifies [pin] against the stored hash. Returns true on match.
  Future<bool> verify(String pin) async {
    final stored = await _readHash();
    if (stored == null) return false;
    final match = _verifyPin(pin, stored);
    if (match) {
      _authenticated = true;
      nookLog(NookLogKey.security, 'PIN verified', LogLevel.info);
      notifyListeners();
    } else {
      nookLog(NookLogKey.security, 'PIN verification failed', LogLevel.warning);
    }
    return match;
  }

  /// Sets a new PIN (hashed with fresh salt). Enables PIN lock.
  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
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

  static Future<PinProvider> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('pin_enabled') ?? false;
    return PinProvider(enabled: isEnabled);
  }

  // ── Hashing helpers ──────────────────────────────────────────────

  Future<String?> _readHash() async {
    const storage = FlutterSecureStorage();
    final hash = await storage.read(key: 'pin_hash');
    return hash;
  }

  Future<void> _writeHash(String hash) async {
    const storage = FlutterSecureStorage();
    // Hash format is "salt:sha256hex" — the salt is embedded in the hash.
    await storage.write(key: 'pin_hash', value: hash);
  }

  /// Hashes a PIN with a random 16-byte salt using SHA-256.
  static String _hashPin(String pin) {
    final salt = _randomSalt();
    final bytes = utf8.encode('$salt:$pin');
    final digest = sha256.convert(bytes);
    return '$salt:${digest.toString()}';
  }

  /// Verifies [pin] against stored [hash].
  static bool _verifyPin(String pin, String hash) {
    final parts = hash.split(':');
    if (parts.length != 2) return false;
    final salt = parts[0];
    final bytes = utf8.encode('$salt:$pin');
    final digest = sha256.convert(bytes);
    return digest.toString() == parts[1];
  }

  static String _randomSalt() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return base64Url.encode(bytes);
  }
}

final pinProvider = ChangeNotifierProvider<PinProvider>((ref) {
  return PinProvider(); // defaults until loaded
});
