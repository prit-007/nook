import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:pointycastle/api.dart';

import 'sync_cipher.dart';
import 'sync_key_exchange.dart';

/// Holds the cryptographic session state for one sync connection.
///
/// A [SyncSessionCipher] starts a plaintext handshake (identity frames) and,
/// once both ECDH public keys are exchanged, derives a shared session key and
/// switches all subsequent frames to AES-256-GCM encryption.
class SyncSessionCipher {
  SyncSessionCipher();

  /// This device's ephemeral ECDH key pair.
  AsymmetricKeyPair<PublicKey, PrivateKey>? _localKeyPair;

  /// True once the session key has been derived and frames are encrypted.
  bool get isActive => _cipher != null;

  /// The underlying frame cipher; null until key exchange completes.
  SyncCipher? _cipher;

  /// The derived session key (used to display the verification PIN).
  crypto.SecretKey? _sessionKey;

  /// Generates this device's ephemeral ECDH key pair.
  Future<AsymmetricKeyPair<PublicKey, PrivateKey>> beginHandshake() async {
    final pair = await SyncKeyExchange.generateKeyPair();
    _localKeyPair = pair;
    return pair;
  }

  /// Returns this device's serialized public key (for the identity frame).
  Uint8List exportPublicKey() {
    final pair = _localKeyPair;
    if (pair == null) {
      throw StateError('Handshake not started');
    }
    return SyncKeyExchange.exportPublicKey(pair.publicKey);
  }

  /// Completes key exchange with the peer's serialized public key and enables
  /// frame encryption.
  Future<void> completeKeyExchange(List<int> remotePublicKeyBytes) async {
    final pair = _localKeyPair;
    if (pair == null) {
      throw StateError('Handshake not started');
    }
    final secret = await SyncKeyExchange.computeSharedSecret(
      pair,
      remotePublicKeyBytes,
    );
    _sessionKey = secret;
    _cipher = SyncCipher(secret);
  }

  /// Derives the 6-digit human verification PIN from the shared secret.
  ///
  /// Both devices must produce the same PIN; a mismatch indicates a MITM or a
  /// wrong pairing code.
  Future<String> derivePin() async {
    final key = _sessionKey;
    if (key == null) {
      throw StateError('Key exchange not complete');
    }
    return SyncCipher.derivePin(key);
  }

  /// Encrypts a frame payload. Before key exchange, returns [payload] as-is.
  Future<List<int>> encryptFrame(List<int> payload) async {
    final cipher = _cipher;
    if (cipher == null) return payload;
    return cipher.encrypt(payload);
  }

  /// Decrypts a frame payload. Before key exchange, returns [frame] as-is.
  Future<List<int>> decryptFrame(List<int> frame) async {
    final cipher = _cipher;
    if (cipher == null) return frame;
    return cipher.decrypt(frame);
  }
}
