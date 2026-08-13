import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/crypto/sync_session_cipher.dart';

void main() {
  group('SyncSessionCipher', () {
    test('both sides derive the same PIN after key exchange', () async {
      final alice = SyncSessionCipher();
      final bob = SyncSessionCipher();

      await alice.beginHandshake();
      await bob.beginHandshake();

      // Exchange public keys (identity frames are plaintext).
      final alicePub = alice.exportPublicKey();
      final bobPub = bob.exportPublicKey();

      await alice.completeKeyExchange(bobPub);
      await bob.completeKeyExchange(alicePub);

      final alicePin = await alice.derivePin();
      final bobPin = await bob.derivePin();

      expect(alicePin, bobPin);
      expect(alicePin, matches(RegExp(r'^\d{6}$')));
    });

    test('frames are plaintext before key exchange and encrypted after',
        () async {
      final alice = SyncSessionCipher();
      final bob = SyncSessionCipher();

      await alice.beginHandshake();
      await bob.beginHandshake();

      // Before exchange: passthrough.
      final plain = utf8.encode('hello');
      expect(await alice.encryptFrame(plain), plain);

      // Complete exchange.
      final alicePub = alice.exportPublicKey();
      final bobPub = bob.exportPublicKey();
      await alice.completeKeyExchange(bobPub);
      await bob.completeKeyExchange(alicePub);

      // After exchange: alice -> bob round-trips, and ciphertext differs.
      final ciphertext = await alice.encryptFrame(plain);
      expect(ciphertext, isNot(equals(plain)));
      final recovered = await bob.decryptFrame(ciphertext);
      expect(utf8.decode(recovered), 'hello');
    });

    test('tampered encrypted frames are rejected', () async {
      final alice = SyncSessionCipher();
      final bob = SyncSessionCipher();

      await alice.beginHandshake();
      await bob.beginHandshake();
      await alice.completeKeyExchange(bob.exportPublicKey());
      await bob.completeKeyExchange(alice.exportPublicKey());

      final ciphertext = await alice.encryptFrame(utf8.encode('secret'));
      ciphertext[ciphertext.length - 1] ^= 0xFF;

      await expectLater(bob.decryptFrame(ciphertext), throwsA(anything));
    });

    test('derivePin fails before key exchange completes', () async {
      final session = SyncSessionCipher();
      await session.beginHandshake();
      await expectLater(session.derivePin(), throwsStateError);
    });
  });
}
