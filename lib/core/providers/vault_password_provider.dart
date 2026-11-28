import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/dek_manager.dart';
import '../security/kdf.dart';
import '../security/secure_kv_store.dart';
import 'talker_provider.dart';

/// Second secret gate + C2 SQLCipher DEK wrapping for the vault.
///
/// Unlocking the app is not enough when vault password is enabled: the
/// SQLCipher database encryption key (DEK) is wrapped with a KEK derived from
/// this password (issue #57), and locked notes also require the active vault
/// session. The password hash lives in platform secure storage; the raw secret
/// is never persisted.
class VaultPasswordProvider extends ChangeNotifier {
  VaultPasswordProvider({
    this.enabled = false,
    SecureKeyValueStore? store,
    DekManager? dekManager,
  })  : _store = store ?? const FlutterSecureKeyValueStore(),
        _dekManager = dekManager ??
            DekManager(store: store ?? const FlutterSecureKeyValueStore());

  static const String _hashKey = 'vault_password_hash';
  static const String _enabledKey = 'vault_password_enabled';

  bool enabled;
  bool _unlocked = false;
  String? _sessionDek;
  final SecureKeyValueStore _store;
  final DekManager _dekManager;

  bool get isUnlocked => _unlocked;
  String? get sessionDek => _sessionDek;

  /// Marks the vault session unlocked with an already-unwrapped [dek]
  /// (used after cold-start C2 DB gate unlock).
  void markUnlockedWithDek(String dek) {
    _sessionDek = dek;
    _unlocked = true;
    notifyListeners();
  }

  /// Verifies [password] against the stored hash and unwraps the DEK if C2
  /// wrapping is active.
  Future<bool> unlock(String password) async {
    final stored = await _store.read(_hashKey);
    if (stored == null) return false;
    final match = await kdfVerify(password: password, storedHash: stored);
    if (match) {
      if (await _dekManager.isWrapped()) {
        _sessionDek = await _dekManager.unwrapDekWithPassword(password);
      }
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

  /// Sets a new vault password (hashed with fresh salt) and wraps the
  /// SQLCipher DEK (C2). Enables the gate.
  Future<void> setPassword(
    String password, {
    dynamic recoveryWords,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be empty');
    }
    final hash = await argon2idHash(password: password);
    await _store.write(_hashKey, hash);

    if (await _dekManager.isWrapped() && _sessionDek != null) {
      await _dekManager.restoreUnwrappedDek(_sessionDek!);
    }
    if (!await _dekManager.isWrapped()) {
      _sessionDek = await _dekManager.wrapDekWithPassword(
        password,
        recoveryWords: recoveryWords,
      );
    }

    enabled = true;
    _unlocked = true;
    nookLog(NookLogKey.security, 'Vault password set', LogLevel.info);
    notifyListeners();
    await _save();
  }

  /// Clears the stored password, restores the unwrapped DEK to keystore if
  /// wrapped, and disables the vault gate.
  Future<void> clearPassword({String? password}) async {
    if (await _dekManager.isWrapped()) {
      if (password != null) {
        await _dekManager.disableWrappingWithPassword(password);
      } else if (_sessionDek != null) {
        await _dekManager.restoreUnwrappedDek(_sessionDek!);
      }
    }
    await _store.delete(_hashKey);
    enabled = false;
    _unlocked = false;
    _sessionDek = null;
    notifyListeners();
    await _save();
  }

  /// Called when the app locks — re-lock the vault session.
  void resetAuth() {
    _unlocked = false;
    _sessionDek = null;
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
