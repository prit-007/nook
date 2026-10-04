import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Default PBKDF2 iteration count for app secrets (PIN, vault password).
///
/// High enough to slow brute-force on short secrets while remaining fast on
/// modern mobile hardware (~200 ms on a Pixel 7 at 100k iterations).
const int defaultPbkdf2Iterations = 100000;

/// Generates a random salt encoded as base64url (may include `=` padding).
///
/// The encoded string is what callers store inside the hash blob; the KDF
/// treats it as UTF-8 bytes when deriving (matching historical PinProvider
/// behavior so existing stored hashes keep verifying).
String generateSalt({int byteLength = 16}) {
  final rng = Random.secure();
  final bytes = List<int>.generate(byteLength, (_) => rng.nextInt(256));
  return base64Url.encode(bytes);
}

/// Hashes [password] with PBKDF2-HMAC-SHA256.
///
/// Stored format: `salt:iterations:derived` where `derived` is the Dart
/// `List<int>.toString()` of the 32-byte key (legacy PinProvider format —
/// not hex — so existing `pin_hash` values continue to verify).
///
/// When [saltBase64] is omitted a fresh random salt is generated.
String pbkdf2Hash({
  required String password,
  String? saltBase64,
  int iterations = defaultPbkdf2Iterations,
}) {
  final salt = saltBase64 ?? generateSalt();
  final derived = pbkdf2DeriveBytes(
    password: password,
    salt: utf8.encode(salt),
    iterations: iterations,
    keyLength: 32,
  );
  return '$salt:$iterations:${derived.toString()}';
}

/// Verifies [password] against a stored `salt:iterations:derived` hash.
///
/// Legacy two-part SHA-256 hashes (`salt:hex`) and malformed blobs return
/// `false` so callers treat them as mismatches (user re-sets the secret).
bool pbkdf2Verify({
  required String password,
  required String storedHash,
}) {
  final parts = storedHash.split(':');
  if (parts.length != 3) return false;
  final salt = parts[0];
  final iterations = int.tryParse(parts[1]);
  if (iterations == null || iterations < 1) return false;
  final derived = pbkdf2DeriveBytes(
    password: password,
    salt: utf8.encode(salt),
    iterations: iterations,
    keyLength: 32,
  );
  return derived.toString() == parts[2];
}

/// Raw PBKDF2-HMAC-SHA256 derivation using the `crypto` package.
///
/// [password] is encoded as UTF-8. [salt] is used as raw bytes.
/// HMAC-SHA256 block size is 64 bytes.
List<int> pbkdf2DeriveBytes({
  required String password,
  required List<int> salt,
  required int iterations,
  required int keyLength,
}) {
  final key = utf8.encode(password);
  final hmac = Hmac(sha256, key);
  final blocks = <int>[];
  for (var i = 1; blocks.length < keyLength; i++) {
    final blockI = hmac.convert([...salt, ..._int32BigEndian(i)]).bytes;
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

List<int> _int32BigEndian(int value) {
  return [
    (value >> 24) & 0xff,
    (value >> 16) & 0xff,
    (value >> 8) & 0xff,
    value & 0xff,
  ];
}
