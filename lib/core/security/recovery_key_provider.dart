import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bip39_wordlist.dart';
import 'kdf.dart';

/// Precomputed word map for O(1) index lookup.
final Map<String, int> _bip39WordMap = {
  for (var i = 0; i < bip39EnglishWordList.length; i++)
    bip39EnglishWordList[i]: i,
};

/// Generates a standardized 24-word BIP-39 recovery mnemonic phrase.
///
/// If [entropy] is provided, it must be exactly 32 bytes (256 bits).
/// Otherwise, 32 cryptographically secure random bytes are generated
/// using [random] (defaults to [Random.secure]).
///
/// The 24 words represent 256 bits of entropy plus an 8-bit SHA-256 checksum
/// (264 bits total, divided into 24 11-bit indexes).
List<String> generateRecoveryKey({List<int>? entropy, Random? random}) {
  final List<int> ent;
  if (entropy != null) {
    if (entropy.length != 32) {
      throw ArgumentError.value(
        entropy.length,
        'entropy',
        'Entropy must be exactly 32 bytes (256 bits) for a 24-word recovery key',
      );
    }
    ent = entropy;
  } else {
    final rng = random ?? Random.secure();
    ent = List<int>.generate(32, (_) => rng.nextInt(256));
  }

  // 1. Calculate SHA-256 checksum (first 8 bits = 1 byte).
  final hash = sha256.convert(ent).bytes;
  final checksum = hash[0];

  // 2. Combine entropy (32 bytes) + checksum (1 byte) = 33 bytes (264 bits).
  final combined = [...ent, checksum];

  // 3. Extract 24 11-bit integers.
  final words = <String>[];
  var bitBuffer = 0;
  var bitCount = 0;
  for (final byte in combined) {
    bitBuffer = (bitBuffer << 8) | byte;
    bitCount += 8;
    while (bitCount >= 11) {
      bitCount -= 11;
      final index = (bitBuffer >> bitCount) & 0x7FF;
      words.add(bip39EnglishWordList[index]);
    }
  }

  return words;
}

/// Validates whether [words] is a valid 24-word BIP-39 recovery key phrase.
///
/// Accepts either a `List<String>` or a whitespace-delimited `String`.
/// Returns `false` if:
/// - The word count is not exactly 24.
/// - Any word is not present in the BIP-39 English dictionary.
/// - The 8-bit checksum encoded in the phrase does not match SHA-256 of the entropy.
bool validateRecoveryKey(dynamic words) {
  final List<String> list;
  if (words is String) {
    final trimmed = words.trim();
    if (trimmed.isEmpty) return false;
    list = trimmed.toLowerCase().split(RegExp(r'\s+'));
  } else if (words is List) {
    list = words
        .map((e) => e.toString().trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
  } else {
    return false;
  }

  if (list.length != 24) return false;

  // Convert each word to its 11-bit index.
  final indices = <int>[];
  for (final word in list) {
    final index = _bip39WordMap[word];
    if (index == null) return false;
    indices.add(index);
  }

  // Reconstruct 264 bits into 33 bytes (32 bytes entropy + 1 byte checksum).
  final bytes = <int>[];
  var bitBuffer = 0;
  var bitCount = 0;
  for (final index in indices) {
    bitBuffer = (bitBuffer << 11) | index;
    bitCount += 11;
    while (bitCount >= 8) {
      bitCount -= 8;
      bytes.add((bitBuffer >> bitCount) & 0xFF);
    }
  }

  if (bytes.length != 33) return false;

  final entropy = bytes.sublist(0, 32);
  final checksum = bytes[32];

  final expectedChecksum = sha256.convert(entropy).bytes[0];
  return checksum == expectedChecksum;
}

/// Derives a deterministic 256-bit (32-byte) Data Encryption Key (DEK)
/// from a valid 24-word recovery key phrase using PBKDF2/HMAC-SHA256 (`kdf.dart`).
///
/// Accepts either a `List<String>` or a whitespace-delimited `String`.
/// Throws [ArgumentError] if the phrase fails [validateRecoveryKey].
List<int> deriveVaultDEKFromRecoveryKey(
  dynamic words, {
  String passphrase = '',
  List<int>? salt,
  int iterations = defaultPbkdf2Iterations,
}) {
  final List<String> list;
  if (words is String) {
    final trimmed = words.trim();
    list = trimmed.isEmpty
        ? <String>[]
        : trimmed.toLowerCase().split(RegExp(r'\s+'));
  } else if (words is List) {
    list = words
        .map((e) => e.toString().trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
  } else {
    throw ArgumentError.value(
        words, 'words', 'Must be a List<String> or String');
  }

  if (!validateRecoveryKey(list)) {
    throw ArgumentError.value(
      words,
      'words',
      'Invalid recovery key phrase: failed validation or checksum mismatch',
    );
  }

  final phrase = list.join(' ');
  final effectiveSalt = salt ?? utf8.encode('mnemonic$passphrase');

  return pbkdf2DeriveBytes(
    password: phrase,
    salt: effectiveSalt,
    iterations: iterations,
    keyLength: 32,
  );
}

/// Service seam for recovery key generation, validation, and key derivation.
class RecoveryKeyService {
  const RecoveryKeyService();

  List<String> generate({List<int>? entropy, Random? random}) =>
      generateRecoveryKey(entropy: entropy, random: random);

  bool validate(dynamic words) => validateRecoveryKey(words);

  List<int> deriveVaultDEK(
    dynamic words, {
    String passphrase = '',
    List<int>? salt,
    int iterations = defaultPbkdf2Iterations,
  }) =>
      deriveVaultDEKFromRecoveryKey(
        words,
        passphrase: passphrase,
        salt: salt,
        iterations: iterations,
      );
}

final recoveryKeyServiceProvider = Provider<RecoveryKeyService>(
  (ref) => const RecoveryKeyService(),
);
