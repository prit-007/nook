import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../providers/talker_provider.dart';
import 'kdf.dart';
import 'recovery_key_provider.dart';
import 'secure_kv_store.dart';

/// Thrown when [openEncryptedDatabase] is called while the SQLCipher DEK is
/// wrapped by a vault password and no unlocked DEK was supplied.
class VaultLockedException implements Exception {
  const VaultLockedException([
    this.message = 'Database encryption key is wrapped by vault password',
  ]);

  final String message;

  @override
  String toString() => 'VaultLockedException: $message';
}

/// Manages C2 SQLCipher Data Encryption Key (DEK) wrapping.
///
/// When vault DEK wrapping is disabled (default), the 32-byte base64 DEK lives
/// in platform secure storage under [dbEncryptionKeyStorageKey].
///
/// When enabled, the DEK is encrypted (AES-256-GCM) under a Key Encryption Key
/// (KEK) derived from the user's vault password via PBKDF2-HMAC-SHA256
/// (`kdf.dart`), stored under [wrappedDekStorageKey], and the unwrapped
/// [dbEncryptionKeyStorageKey] is removed from secure storage so the SQLCipher
/// database cannot be opened without the vault password (or 24-word recovery
/// key when [recoveryWrappedDekStorageKey] is configured).
class DekManager {
  DekManager({
    SecureKeyValueStore? store,
    this.iterations = defaultPbkdf2Iterations,
    this.argon2Memory = defaultArgon2Memory,
    this.argon2Iterations = defaultArgon2Iterations,
    this.argon2Parallelism = defaultArgon2Parallelism,
    Random? random,
  })  : _store = store ?? const FlutterSecureKeyValueStore(),
        _random = random ?? Random.secure();

  static const String dbEncryptionKeyStorageKey = 'db_encryption_key';
  static const String wrappedDekStorageKey = 'vault_wrapped_dek';
  static const String recoveryWrappedDekStorageKey =
      'vault_recovery_wrapped_dek';

  final SecureKeyValueStore _store;
  final int iterations;
  final int argon2Memory;
  final int argon2Iterations;
  final int argon2Parallelism;
  final Random _random;
  final AesGcm _aesGcm = AesGcm.with256bits();

  /// Recovers from an interrupted wrap if the app was killed mid-operation.
  ///
  /// - If both [dbEncryptionKeyStorageKey] and [wrappedDekStorageKey] exist:
  ///   - When [wrappedDekStorageKey] is structurally valid, finishes the wrap
  ///     by deleting the plaintext key.
  ///   - When [wrappedDekStorageKey] is corrupt/partial, deletes the partial
  ///     wrapped blobs so [dbEncryptionKeyStorageKey] remains intact.
  Future<void> recoverInterruptedWrap() async {
    final plain = await _store.read(dbEncryptionKeyStorageKey);
    final wrappedRaw = await _store.read(wrappedDekStorageKey);
    if (plain == null || plain.isEmpty || wrappedRaw == null) {
      return;
    }

    if (_isValidEnvelopeJson(wrappedRaw)) {
      await _store.delete(dbEncryptionKeyStorageKey);
      nookLog(
        NookLogKey.security,
        'Completed interrupted C2 DEK wrap cleanup',
        LogLevel.info,
      );
    } else {
      await _store.delete(wrappedDekStorageKey);
      await _store.delete(recoveryWrappedDekStorageKey);
      nookLog(
        NookLogKey.security,
        'Rolled back corrupt partial C2 DEK wrap; plaintext key preserved',
        LogLevel.warning,
      );
    }
  }

  bool _isValidEnvelopeJson(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return false;
      final salt = map['salt'];
      final nonce = map['nonce'];
      final ciphertext = map['ciphertext'];
      final mac = map['mac'];
      if (salt is! String ||
          salt.isEmpty ||
          nonce is! String ||
          nonce.isEmpty ||
          ciphertext is! String ||
          ciphertext.isEmpty ||
          mac is! String ||
          mac.isEmpty) {
        return false;
      }
      final version = map['v'];
      if (version == 2) {
        final kdf = map['kdf'];
        return kdf is String && kdf.startsWith(argon2idPrefix);
      }
      final iters = map['iterations'];
      return iters is int && iters > 0;
    } catch (_) {
      return false;
    }
  }

  /// Returns `true` when the SQLCipher DEK is wrapped by a vault password.
  Future<bool> isWrapped() async {
    final blob = await _store.read(wrappedDekStorageKey);
    return blob != null && blob.isNotEmpty;
  }

  /// Returns `true` when a recovery-key-wrapped backup of the DEK exists.
  Future<bool> hasRecoveryWrappedDek() async {
    final blob = await _store.read(recoveryWrappedDekStorageKey);
    return blob != null && blob.isNotEmpty;
  }

  /// Wraps the current (or newly generated) DEK with [password].
  ///
  /// If [recoveryWords] (a valid 24-word BIP-39 phrase) is provided, also
  /// stores a recovery-wrapped copy under [recoveryWrappedDekStorageKey].
  /// Deletes the plaintext [dbEncryptionKeyStorageKey] once wrapped.
  Future<String> wrapDekWithPassword(
    String password, {
    dynamic recoveryWords,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be empty');
    }

    var dek = await _store.read(dbEncryptionKeyStorageKey);
    if (dek == null || dek.isEmpty) {
      // If already wrapped, caller must rotate/unwrap first rather than
      // silently overwriting an existing wrapped DEK.
      if (await isWrapped()) {
        throw StateError('DEK is already wrapped; use rotatePassword instead');
      }
      dek = _generateRandomBase64Key(32);
    }

    final wrappedJson = await _encryptDekV2WithPassword(
      dek: dek,
      password: password,
    );
    await _store.write(wrappedDekStorageKey, wrappedJson);

    if (recoveryWords != null) {
      await _writeRecoveryWrappedDek(dek, recoveryWords);
    }

    // Verify the written wrapped envelope decrypts to the exact DEK before
    // deleting the plaintext key from secure storage.
    final verified = await unwrapDekWithPassword(password);
    if (verified != dek) {
      await _store.delete(wrappedDekStorageKey);
      await _store.delete(recoveryWrappedDekStorageKey);
      throw StateError('DEK wrap verification failed; plaintext key preserved');
    }

    await _store.delete(dbEncryptionKeyStorageKey);
    nookLog(
      NookLogKey.security,
      'SQLCipher DEK wrapped with vault password (C2)',
      LogLevel.info,
    );
    return dek;
  }

  /// Stores a recovery-key-wrapped copy of [dek] so the user can recover
  /// database access using their 24-word BIP-39 phrase if they forget their
  /// vault password.
  Future<void> wrapDekWithRecoveryKey(String dek, dynamic recoveryWords) async {
    await _writeRecoveryWrappedDek(dek, recoveryWords);
  }

  Future<void> _writeRecoveryWrappedDek(
    String dek,
    dynamic recoveryWords,
  ) async {
    final recoveryKek = deriveVaultDEKFromRecoveryKey(
      recoveryWords,
      iterations: iterations,
    );
    final wrappedJson = await _encryptDekWithKek(
      dek: dek,
      kekBytes: recoveryKek,
      salt: 'mnemonic',
      iterations: iterations,
    );
    await _store.write(recoveryWrappedDekStorageKey, wrappedJson);
  }

  /// Unwraps the DEK using [password]. Returns `null` on wrong password or
  /// missing/corrupt envelope.
  ///
  /// When a legacy `v1` PBKDF2 envelope is unwrapped successfully, it is
  /// atomically migrated to `v2` Argon2id; a failed unwrap or failed write
  /// never corrupts the stored DEK.
  Future<String?> unwrapDekWithPassword(String password) async {
    final raw = await _store.read(wrappedDekStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final version = map['v'];
      if (version == 2) {
        return await _unwrapV2Envelope(map: map, password: password);
      }

      // Legacy v1 PBKDF2 envelope.
      final salt = map['salt'] as String;
      final iters = map['iterations'] as int;
      final kek = pbkdf2DeriveBytes(
        password: password,
        salt: utf8.encode(salt),
        iterations: iters,
        keyLength: 32,
      );
      final dek = await _decryptDekWithKek(map: map, kekBytes: kek);
      if (dek != null) {
        await _migrateLegacyEnvelopeToV2(dek: dek, password: password);
      }
      return dek;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _unwrapV2Envelope({
    required Map<String, dynamic> map,
    required String password,
  }) async {
    final kdf = map['kdf'];
    if (kdf is! String || !kdf.startsWith(argon2idPrefix)) return null;
    final parts = kdf.split('\$');
    if (parts.length < 4) return null;
    final params = parseArgon2idParams(parts[2]);
    if (params == null) return null;
    final salt = map['salt'] as String;
    final kek = await argon2idDeriveBytes(
      password: password,
      salt: utf8.encode(salt),
      memory: params.memory,
      iterations: params.iterations,
      parallelism: params.parallelism,
      keyLength: 32,
    );
    return _decryptDekWithKek(map: map, kekBytes: kek);
  }

  Future<void> _migrateLegacyEnvelopeToV2({
    required String dek,
    required String password,
  }) async {
    try {
      final v2Json = await _encryptDekV2WithPassword(
        dek: dek,
        password: password,
      );
      final v2Map = jsonDecode(v2Json) as Map<String, dynamic>;
      final verified = await _unwrapV2Envelope(map: v2Map, password: password);
      if (verified != dek) {
        nookLog(
          NookLogKey.security,
          'Argon2id KDF migration verification failed; keeping legacy envelope',
          LogLevel.warning,
        );
        return;
      }
      await _store.write(wrappedDekStorageKey, v2Json);
      nookLog(
        NookLogKey.security,
        'Migrated wrapped DEK KDF from PBKDF2 to v2 Argon2id',
        LogLevel.info,
      );
    } catch (e) {
      // Never fail or corrupt the stored DEK if migration write is interrupted.
      nookLog(
        NookLogKey.security,
        'Interrupted Argon2id KDF migration rolled back ($e)',
        LogLevel.warning,
      );
    }
  }

  /// Unwraps the DEK using a 24-word BIP-39 [recoveryWords] phrase.
  /// Returns `null` if invalid or authentication fails.
  Future<String?> unwrapDekWithRecoveryKey(dynamic recoveryWords) async {
    final raw = await _store.read(recoveryWrappedDekStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final iters = (map['iterations'] as int?) ?? iterations;
      final recoveryKek = deriveVaultDEKFromRecoveryKey(
        recoveryWords,
        iterations: iters,
      );
      return await _decryptDekWithKek(map: map, kekBytes: recoveryKek);
    } catch (_) {
      return null;
    }
  }

  /// Re-wraps the DEK with [newPassword] after verifying [oldPassword].
  Future<bool> rotatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (newPassword.isEmpty) {
      throw ArgumentError.value(
          newPassword, 'newPassword', 'must not be empty');
    }
    final dek = await unwrapDekWithPassword(oldPassword);
    if (dek == null) return false;

    final wrappedJson = await _encryptDekV2WithPassword(
      dek: dek,
      password: newPassword,
    );
    await _store.write(wrappedDekStorageKey, wrappedJson);
    return true;
  }

  /// Unwraps the DEK using [password], restores it to
  /// [dbEncryptionKeyStorageKey], and removes the wrapped envelopes.
  Future<bool> disableWrappingWithPassword(String password) async {
    final dek = await unwrapDekWithPassword(password);
    if (dek == null) return false;
    await restoreUnwrappedDek(dek);
    return true;
  }

  /// Persists an already-unwrapped [dek] back into [dbEncryptionKeyStorageKey]
  /// and removes the wrapped envelopes (used when disabling vault password).
  Future<void> restoreUnwrappedDek(String dek) async {
    await _store.write(dbEncryptionKeyStorageKey, dek);
    await _store.delete(wrappedDekStorageKey);
    await _store.delete(recoveryWrappedDekStorageKey);
    nookLog(
      NookLogKey.security,
      'SQLCipher DEK wrapping disabled; key restored to keystore',
      LogLevel.info,
    );
  }

  Future<String> _encryptDekV2WithPassword({
    required String dek,
    required String password,
  }) async {
    final salt = generateSalt();
    final kek = await argon2idDeriveBytes(
      password: password,
      salt: utf8.encode(salt),
      memory: argon2Memory,
      iterations: argon2Iterations,
      parallelism: argon2Parallelism,
      keyLength: 32,
    );
    final nonce = List<int>.generate(12, (_) => _random.nextInt(256));
    final box = await _aesGcm.encrypt(
      utf8.encode(dek),
      secretKey: SecretKey(kek),
      nonce: nonce,
    );
    return jsonEncode({
      'v': 2,
      'kdf':
          '${argon2idPrefix}m=$argon2Memory,t=$argon2Iterations,p=$argon2Parallelism\$$salt',
      'salt': salt,
      'nonce': base64Url.encode(box.nonce),
      'ciphertext': base64Url.encode(box.cipherText),
      'mac': base64Url.encode(box.mac.bytes),
    });
  }

  /// Creates a legacy v1 PBKDF2-wrapped envelope for migration testing.
  @visibleForTesting
  Future<String> encryptLegacyV1ForTest({
    required String dek,
    required String password,
    int? iterations,
  }) async {
    final salt = generateSalt();
    final iters = iterations ?? this.iterations;
    final kek = pbkdf2DeriveBytes(
      password: password,
      salt: utf8.encode(salt),
      iterations: iters,
      keyLength: 32,
    );
    return _encryptDekWithKek(
      dek: dek,
      kekBytes: kek,
      salt: salt,
      iterations: iters,
    );
  }

  Future<String> _encryptDekWithKek({
    required String dek,
    required List<int> kekBytes,
    required String salt,
    required int iterations,
  }) async {
    final nonce = List<int>.generate(12, (_) => _random.nextInt(256));
    final secretKey = SecretKey(kekBytes);
    final box = await _aesGcm.encrypt(
      utf8.encode(dek),
      secretKey: secretKey,
      nonce: nonce,
    );
    return jsonEncode({
      'v': 1,
      'salt': salt,
      'iterations': iterations,
      'nonce': base64Url.encode(box.nonce),
      'ciphertext': base64Url.encode(box.cipherText),
      'mac': base64Url.encode(box.mac.bytes),
    });
  }

  Future<String?> _decryptDekWithKek({
    required Map<String, dynamic> map,
    required List<int> kekBytes,
  }) async {
    final nonce = base64Url.decode(map['nonce'] as String);
    final cipherText = base64Url.decode(map['ciphertext'] as String);
    final mac = Mac(base64Url.decode(map['mac'] as String));
    final box = SecretBox(cipherText, nonce: nonce, mac: mac);
    final clearBytes = await _aesGcm.decrypt(
      box,
      secretKey: SecretKey(kekBytes),
    );
    return utf8.decode(clearBytes);
  }

  String _generateRandomBase64Key(int byteLength) {
    final bytes = List<int>.generate(byteLength, (_) => _random.nextInt(256));
    return base64.encode(bytes);
  }
}
