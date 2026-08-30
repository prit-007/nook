import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'talker_provider.dart';

/// Number of PBKDF2 iterations — high enough to slow brute-force on a 6-digit
/// PIN while remaining fast on modern mobile hardware (~200 ms on a Pixel 7).
const _pbkdf2Iterations = 100000;

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

  /// Hashes a PIN with a random 16-byte salt using PBKDF2-HMAC-SHA256.
  ///
  /// The hash format is `salt:iterations:derived_hex`. Older SHA-256 hashes
  /// (format `salt:hex`) are rejected gracefully by [_verifyPin] and treated
  /// as a mismatch so the user is prompted to re-set their PIN.
  static String _hashPin(String pin) {
    final salt = _randomSalt();
    final derived = _pbkdf2(pin, salt);
    return '$salt:$_pbkdf2Iterations:${derived.toString()}';
  }

  /// Verifies [pin] against stored [hash].
  static bool _verifyPin(String pin, String hash) {
    final parts = hash.split(':');
    // Legacy SHA-256 format has exactly 2 parts; PBKDF2 format has 3.
    if (parts.length == 3) {
      final salt = parts[0];
      final iterations = int.tryParse(parts[1]);
      if (iterations == null || iterations < 1) return false;
      final derived = _pbkdf2(pin, salt, iterations: iterations);
      return derived.toString() == parts[2];
    }
    // Legacy format — always mismatch so the user must re-set their PIN.
    return false;
  }

  /// Derives a 32-byte key from [pin] + [salt] using PBKDF2-HMAC-SHA256.
  static List<int> _pbkdf2(String pin, String salt,
      {int iterations = _pbkdf2Iterations}) {
    final key = utf8.encode(pin);
    final saltBytes = utf8.encode(salt);
    // HMAC-SHA256 block size is 64 bytes; derive 32 bytes (256 bits).
    return _pbkdf2Derive(key, saltBytes, iterations, 32, 64);
  }

  /// Raw PBKDF2-HMAC-SHA256 implementation using the `crypto` package.
  static List<int> _pbkdf2Derive(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
    int blockLength,
  ) {
    final hmac = Hmac(sha256, password);
    final blocks = <int>[];
    for (var i = 1; blocks.length < keyLength; i++) {
      final blockI = hmac.convert(
        [...salt, ..._int32BigEndian(i)],
      ).bytes;
      var u = blockI;
      var xored = List<int>.from(u);
      for (var j = 1; j < iterations; j++) {
        u = hmac.convert(u).bytes;
        for (var k = 0; k < u.length; k++) {
          xored[k] ^= u[k];
        }
      }
      blocks.addAll(xored);
    }
    return blocks.sublist(0, keyLength);
  }

  static List<int> _int32BigEndian(int value) {
    return [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
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
