import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto_pkg;

/// Default PBKDF2 iteration count for legacy app secrets (PIN, vault password).
///
/// High enough to slow brute-force on short secrets while remaining fast on
/// modern mobile hardware (~200 ms on a Pixel 7 at 100k iterations).
const int defaultPbkdf2Iterations = 100000;

/// Default Argon2id parameters (OWASP minimum interactive profile: 19 MiB,
/// 2 iterations, 1 lane).
const int defaultArgon2Memory = 19456;
const int defaultArgon2Iterations = 2;
const int defaultArgon2Parallelism = 1;

const String argon2idPrefix = 'v2\$argon2id\$';

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

/// Derives [keyLength] bytes from [password] and raw [salt] bytes using Argon2id.
Future<List<int>> argon2idDeriveBytes({
  required String password,
  required List<int> salt,
  int memory = defaultArgon2Memory,
  int iterations = defaultArgon2Iterations,
  int parallelism = defaultArgon2Parallelism,
  int keyLength = 32,
}) async {
  final algorithm = crypto_pkg.Argon2id(
    parallelism: parallelism,
    memory: memory,
    iterations: iterations,
    hashLength: keyLength,
  );
  final secretKey = await algorithm.deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );
  return secretKey.extractBytes();
}

/// Hashes [password] with Argon2id using the versioned `v2$argon2id$...` format:
/// `v2$argon2id$m=<memory>,t=<iterations>,p=<parallelism>$<salt>$<derivedBase64>`.
Future<String> argon2idHash({
  required String password,
  String? saltBase64,
  int memory = defaultArgon2Memory,
  int iterations = defaultArgon2Iterations,
  int parallelism = defaultArgon2Parallelism,
}) async {
  final salt = saltBase64 ?? generateSalt();
  final derived = await argon2idDeriveBytes(
    password: password,
    salt: utf8.encode(salt),
    memory: memory,
    iterations: iterations,
    parallelism: parallelism,
    keyLength: 32,
  );
  return '${argon2idPrefix}m=$memory,t=$iterations,p=$parallelism\$$salt\$${base64Url.encode(derived)}';
}

/// Parses `m=<memory>,t=<iterations>,p=<parallelism>` from a v2 Argon2id header.
({int memory, int iterations, int parallelism})? parseArgon2idParams(
  String paramsSegment,
) {
  int? memory;
  int? iterations;
  int? parallelism;
  for (final token in paramsSegment.split(',')) {
    final kv = token.split('=');
    if (kv.length != 2) return null;
    final value = int.tryParse(kv[1]);
    if (value == null || value < 1) return null;
    switch (kv[0]) {
      case 'm':
        memory = value;
      case 't':
        iterations = value;
      case 'p':
        parallelism = value;
      default:
        return null;
    }
  }
  if (memory == null || iterations == null || parallelism == null) {
    return null;
  }
  return (memory: memory, iterations: iterations, parallelism: parallelism);
}

/// Verifies [password] against a `v2$argon2id$...` stored hash.
Future<bool> argon2idVerify({
  required String password,
  required String storedHash,
}) async {
  if (!storedHash.startsWith(argon2idPrefix)) return false;
  final parts = storedHash.split('\$');
  if (parts.length != 5) return false;
  if (parts[0] != 'v2' || parts[1] != 'argon2id') return false;
  final params = parseArgon2idParams(parts[2]);
  if (params == null) return false;
  final salt = parts[3];
  if (salt.isEmpty) return false;
  late final List<int> expected;
  try {
    expected = base64Url.decode(parts[4]);
  } catch (_) {
    return false;
  }
  if (expected.isEmpty) return false;

  final derived = await argon2idDeriveBytes(
    password: password,
    salt: utf8.encode(salt),
    memory: params.memory,
    iterations: params.iterations,
    parallelism: params.parallelism,
    keyLength: expected.length,
  );
  return _constantTimeEquals(derived, expected);
}

/// Returns `true` when [storedHash] uses the legacy `salt:iterations:derived`
/// PBKDF2 format rather than `v2$argon2id$...`.
bool isLegacyPbkdf2Hash(String storedHash) {
  return !storedHash.startsWith(argon2idPrefix) &&
      storedHash.split(':').length == 3;
}

/// Verifies [password] against either a `v2$argon2id$...` hash or a legacy
/// `salt:iterations:derived` PBKDF2 hash.
Future<bool> kdfVerify({
  required String password,
  required String storedHash,
}) async {
  if (storedHash.startsWith(argon2idPrefix)) {
    return argon2idVerify(password: password, storedHash: storedHash);
  }
  return pbkdf2Verify(password: password, storedHash: storedHash);
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
