import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto;

/// End-to-end encryption layer for the sync protocol.
///
/// Uses AES-256-GCM (authenticated encryption) with a counter-based nonce
/// derived from the session key. Each frame sent over TCP is encrypted
/// before length-prefixing, and decrypted after reading the raw payload.
///
/// Frame format:
///   [nonce 12B] [ciphertext] [mac 16B]
///
/// These are produced by [SecretBox.concatenation] and consumed by
/// [SecretBox.fromConcatenation].
class SyncCipher {
  SyncCipher(this._sessionKey);

  final SecretKey _sessionKey;

  /// AES-GCM-256 authenticated cipher.
  static final AesGcm _aesGcm = AesGcm.with256bits();

  /// Monotonically increasing counter for nonces (sender side).
  int _sendCounter = 0;

  /// Encrypts [plaintext] and returns `[nonce(12) + ciphertext + mac(16)]`.
  Future<List<int>> encrypt(List<int> plaintext) async {
    final nonce = _nextNonce(_sendCounter);
    _sendCounter++;

    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: _sessionKey,
      nonce: nonce,
    );
    return Uint8List.fromList(secretBox.concatenation());
  }

  /// Decrypts a frame produced by [encrypt].
  ///
  /// Throws if authentication fails (tampered data) or the frame is malformed.
  Future<List<int>> decrypt(List<int> frame) async {
    final secretBox = SecretBox.fromConcatenation(
      frame,
      nonceLength: 12,
      macLength: 16,
    );
    return await _aesGcm.decrypt(secretBox, secretKey: _sessionKey);
  }

  /// Derives a 6-digit PIN from the session key for visual verification.
  ///
  /// Both devices must derive the same PIN from the shared ECDH secret.
  /// If an attacker performed a MITM, the PINs will differ.
  static Future<String> derivePin(SecretKey secret) async {
    final keyBytes = await secret.extractBytes();
    final digest = crypto.sha256.convert(keyBytes);
    final bytes = digest.bytes;
    // Take the first 4 bytes as a 32-bit unsigned integer and mod 10^6.
    final value =
        (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
    final pin = (value & 0x7FFFFFFF) % 1000000;
    return pin.toString().padLeft(6, '0');
  }

  /// Generates a 12-byte counter-based nonce for AES-GCM.
  static Uint8List _nextNonce(int counter) {
    final nonce = Uint8List(12);
    // Encode counter in the last 8 bytes (big-endian) of the 12-byte nonce.
    // First 4 bytes are reserved (zeroed) for session uniqueness.
    nonce[4] = (counter >> 56) & 0xFF;
    nonce[5] = (counter >> 48) & 0xFF;
    nonce[6] = (counter >> 40) & 0xFF;
    nonce[7] = (counter >> 32) & 0xFF;
    nonce[8] = (counter >> 24) & 0xFF;
    nonce[9] = (counter >> 16) & 0xFF;
    nonce[10] = (counter >> 8) & 0xFF;
    nonce[11] = counter & 0xFF;
    return nonce;
  }
}
