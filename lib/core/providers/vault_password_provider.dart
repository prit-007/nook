import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/kdf.dart';
import '../security/secure_kv_store.dart';
import 'talker_provider.dart';

/// Second secret gate for sensitive notes (C1 — session gate).
///
/// Unlocking the app is not enough when vault password is enabled: opening a
/// locked note also requires the vault password. The password hash lives in
/// platform secure storage; the raw secret is never persisted.
///
/// This is intentionally **not** SQLCipher DEK wrapping (C2 — issue #57).
/// Exported `.nook` vaults remain plaintext-on-disk; the privacy explainer
/// documents that limitation.
class VaultPasswordProvider extends ChangeNotifier {
  VaultPasswordProvider({
    this.enabled = false,
    SecureKeyValueStore? store,
  }) : _store = store ?? const FlutterSecureKeyValueStore();

  static const String _hashKey = 'vault_password_hash';
  static const String _enabledKey = 'vault_password_enabled';

  bool enabled;
  bool _unlocked = false;
  final SecureKeyValueStore _store;

  bool get isUnlocked => _unlocked;

  /// Verifies [password] against the stored hash.
  Future<bool> unlock(String password) async {
    final stored = await _store.read(_hashKey);
    if (stored == null) return false;
    final match = pbkdf2Verify(password: password, storedHash: stored);
    if (match) {
      _unlocked = true;
      nookLog(NookLogKey.security, 'Vault password unlocked', LogLevel.info);
      notifyListeners();
    } else {
      nookLog(
        NookLogKey.security,
        'Vault password verification failed',
        LogLevel.warning,
      );
    }
    return match;
  }

  /// Sets a new vault password (hashed with fresh salt). Enables the gate.
  Future<void> setPassword(String password) async {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be empty');
    }
    final hash = pbkdf2Hash(password: password);
    await _store.write(_hashKey, hash);
    enabled = true;
    _unlocked = true;
    nookLog(NookLogKey.security, 'Vault password set', LogLevel.info);
    notifyListeners();
    await _save();
  }

  /// Clears the stored password and disables the vault gate.
  Future<void> clearPassword() async {
    await _store.delete(_hashKey);
    enabled = false;
    _unlocked = false;
    notifyListeners();
    await _save();
  }

  /// Called when the app locks — re-lock the vault session.
  void resetAuth() {
    _unlocked = false;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  static Future<VaultPasswordProvider> load({
    SecureKeyValueStore? store,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(_enabledKey) ?? false;
    return VaultPasswordProvider(enabled: isEnabled, store: store);
  }
}

final vaultPasswordProvider = ChangeNotifierProvider<VaultPasswordProvider>(
  (ref) => VaultPasswordProvider(),
);
