import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/secp256r1.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/ec_key_generator.dart';
import 'package:pointycastle/random/fortuna_random.dart';

/// ECDH P-256 key exchange for the sync protocol.
///
/// Uses pointycastle (pure Dart, works in tests and on all platforms) for
/// ephemeral P-256 key generation and shared-secret agreement. After pairing,
/// both devices derive the same shared session key, which is then passed to
/// [SyncCipher] for AES-256-GCM encryption of all frames.
///
/// Public keys are serialized in SEC1 uncompressed form:
///   `[0x04][x: 32 bytes][y: 32 bytes]` (65 bytes)
class SyncKeyExchange {
  SyncKeyExchange._();

  /// P-256 (secp256r1) domain parameters.
  static final ECDomainParameters _curve = ECCurve_secp256r1();

  /// Generates an ephemeral ECDH P-256 key pair.
  static Future<AsymmetricKeyPair<PublicKey, PrivateKey>>
      generateKeyPair() async {
    final generator = ECKeyGenerator();
    final random = _secureRandom();
    generator.init(
      ParametersWithRandom(ECKeyGeneratorParameters(_curve), random),
    );
    final pair = generator.generateKeyPair();
    return AsymmetricKeyPair<PublicKey, PrivateKey>(
      pair.publicKey,
      pair.privateKey,
    );
  }

  /// Serializes the public key to SEC1 uncompressed bytes (65 bytes).
  static Uint8List exportPublicKey(PublicKey publicKey) {
    final point = (publicKey as ECPublicKey).Q;
    if (point == null) {
      throw ArgumentError('Public key has no point');
    }
    final x = _bigIntToPaddedBytes(point.x!.toBigInteger()!, 32);
    final y = _bigIntToPaddedBytes(point.y!.toBigInteger()!, 32);
    final bytes = Uint8List(1 + x.length + y.length);
    bytes[0] = 0x04;
    bytes.setRange(1, 1 + x.length, x);
    bytes.setRange(1 + x.length, 1 + x.length + y.length, y);
    return bytes;
  }

  /// Computes a shared secret from the local [keyPair] and a serialized
  /// remote public key. Returns a 32-byte [crypto.SecretKey].
  static Future<crypto.SecretKey> computeSharedSecret(
    AsymmetricKeyPair<PublicKey, PrivateKey> keyPair,
    List<int> remotePublicKeyBytes,
  ) async {
    final remotePoint = _curve.curve.decodePoint(remotePublicKeyBytes);
    if (remotePoint == null) {
      throw ArgumentError('Invalid remote public key');
    }
    final remotePublic = ECPublicKey(remotePoint, _curve);

    final agreement = ECDHBasicAgreement()
      ..init(keyPair.privateKey as ECPrivateKey);
    final shared = agreement.calculateAgreement(remotePublic);

    // ECDH on P-256 yields the x-coordinate of the shared point (32 bytes).
    final sharedBytes = _bigIntToPaddedBytes(shared, 32);

    // Derive a 32-byte key for AES-256-GCM via HKDF-SHA256 so the raw ECDH
    // x-coordinate is never used directly.
    final hkdf = crypto.Hkdf(hmac: crypto.Hmac.sha256(), outputLength: 32);
    final derived = await hkdf.deriveKey(
      secretKey: crypto.SecretKey(sharedBytes),
      info: Uint8List.fromList(_kdfInfo),
    );
    return derived;
  }

  static const List<int> _kdfInfo = [0x6E, 0x6F, 0x6F, 0x6B]; // "nook"

  static Uint8List _bigIntToPaddedBytes(BigInt value, int length) {
    final hex = value.toRadixString(16).padLeft(length * 2, '0');
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static SecureRandom _secureRandom() {
    final random = FortunaRandom();
    final secure = Random.secure();
    final seed = Uint8List(32);
    for (var i = 0; i < seed.length; i++) {
      seed[i] = secure.nextInt(256);
    }
    random.seed(KeyParameter(seed));
    return random;
  }
}
