import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/crypto/sync_cipher.dart';

void main() {
  group('SyncCipher', () {
    test('encrypt/decrypt round-trips arbitrary payloads', () async {
      final key = SecretKey(await _randomBytes(32));
      final cipher = SyncCipher(key);

      final plaintext = utf8.encode('{"type":"sync_header","bundleId":"abc"}');
      final encrypted = await cipher.encrypt(plaintext);
      final decrypted = await cipher.decrypt(encrypted);

      expect(utf8.decode(decrypted), utf8.decode(plaintext));
    });

    test('binary payload round-trips byte-for-byte', () async {
      final key = SecretKey(await _randomBytes(32));
      final cipher = SyncCipher(key);

      final plaintext = Uint8List.fromList(List<int>.generate(256, (i) => i));
      final decrypted = await cipher.decrypt(await cipher.encrypt(plaintext));

      expect(decrypted, plaintext);
    });

    test('produces a distinct nonce per frame (no nonce reuse)', () async {
      final key = SecretKey(await _randomBytes(32));
      final cipher = SyncCipher(key);

      final plaintext = utf8.encode('same payload');
      final a = await cipher.encrypt(plaintext);
      final b = await cipher.encrypt(plaintext);

      // Nonce is the first 12 bytes of the frame.
      final nonceA = a.sublist(0, 12);
      final nonceB = b.sublist(0, 12);
      expect(nonceA, isNot(equals(nonceB)));
    });

    test('tampered ciphertext fails authentication', () async {
      final key = SecretKey(await _randomBytes(32));
      final cipher = SyncCipher(key);

      final encrypted = await cipher.encrypt(utf8.encode('secret payload'));
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF; // flip a bit in the auth tag

      await expectLater(cipher.decrypt(tampered), throwsA(anything));
    });

    test('decrypt rejects a frame with a too-short payload', () async {
      final key = SecretKey(await _randomBytes(32));
      final cipher = SyncCipher(key);

      await expectLater(
        cipher.decrypt(Uint8List.fromList([1, 2, 3])),
        throwsA(anything),
      );
    });

    test('derivePin produces a stable 6-digit code for a given secret',
        () async {
      final key = SecretKey(await _randomBytes(32));
      final pin1 = await SyncCipher.derivePin(key);
      final pin2 = await SyncCipher.derivePin(key);

      expect(pin1, matches(RegExp(r'^\d{6}$')));
      expect(pin1, pin2);
    });

    test('derivePin differs across different secrets', () async {
      final keyA = SecretKey(await _randomBytes(32));
      final keyB = SecretKey(await _randomBytes(32));

      final pinA = await SyncCipher.derivePin(keyA);
      final pinB = await SyncCipher.derivePin(keyB);

      expect(pinA, isNot(pinB));
    });
  });
}

Future<List<int>> _randomBytes(int length) async {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}
