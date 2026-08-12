import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/crypto/sync_cipher.dart';
import 'package:nook/sync/crypto/sync_key_exchange.dart';

void main() {
  group('SyncKeyExchange', () {
    test('two parties derive the same shared secret via ECDH', () async {
      final alice = await SyncKeyExchange.generateKeyPair();
      final bob = await SyncKeyExchange.generateKeyPair();

      final alicePublic = SyncKeyExchange.exportPublicKey(alice.publicKey);
      final bobPublic = SyncKeyExchange.exportPublicKey(bob.publicKey);

      final aliceSecret =
          await SyncKeyExchange.computeSharedSecret(alice, bobPublic);
      final bobSecret =
          await SyncKeyExchange.computeSharedSecret(bob, alicePublic);

      final aliceBytes = await aliceSecret.extractBytes();
      final bobBytes = await bobSecret.extractBytes();

      expect(aliceBytes, bobBytes);
      expect(aliceBytes.length, greaterThanOrEqualTo(16));
    });

    test('exported public keys are stable byte arrays', () async {
      final keyPair = await SyncKeyExchange.generateKeyPair();
      final pub1 = SyncKeyExchange.exportPublicKey(keyPair.publicKey);
      final pub2 = SyncKeyExchange.exportPublicKey(keyPair.publicKey);

      expect(pub1, pub2);
      expect(pub1.length, greaterThan(0));
    });

    test('an attacker with an unrelated key derives a different secret',
        () async {
      final alice = await SyncKeyExchange.generateKeyPair();
      final bob = await SyncKeyExchange.generateKeyPair();
      final mallory = await SyncKeyExchange.generateKeyPair();

      final alicePublic = SyncKeyExchange.exportPublicKey(alice.publicKey);
      final bobPublic = SyncKeyExchange.exportPublicKey(bob.publicKey);

      final aliceSecret =
          await SyncKeyExchange.computeSharedSecret(alice, bobPublic);
      final mallorySecret =
          await SyncKeyExchange.computeSharedSecret(mallory, alicePublic);

      final aliceBytes = await aliceSecret.extractBytes();
      final malloryBytes = await mallorySecret.extractBytes();

      expect(aliceBytes, isNot(equals(malloryBytes)));
    });

    test('shared secret is a 32-byte AES-GCM-ready key', () async {
      final alice = await SyncKeyExchange.generateKeyPair();
      final bob = await SyncKeyExchange.generateKeyPair();

      final bobPublic = SyncKeyExchange.exportPublicKey(bob.publicKey);

      final aliceSecret =
          await SyncKeyExchange.computeSharedSecret(alice, bobPublic);
      final bytes = await aliceSecret.extractBytes();

      expect(bytes.length, 32);
    });

    test('a cipher using derived keys encrypts across both parties', () async {
      final alice = await SyncKeyExchange.generateKeyPair();
      final bob = await SyncKeyExchange.generateKeyPair();

      final alicePublic = SyncKeyExchange.exportPublicKey(alice.publicKey);
      final bobPublic = SyncKeyExchange.exportPublicKey(bob.publicKey);

      final aliceSecret =
          await SyncKeyExchange.computeSharedSecret(alice, bobPublic);
      final bobSecret =
          await SyncKeyExchange.computeSharedSecret(bob, alicePublic);

      final aliceCipher = SyncCipher(aliceSecret);
      final bobCipher = SyncCipher(bobSecret);

      final ciphertext =
          await aliceCipher.encrypt('hello over the wire'.codeUnits);
      final plaintext = await bobCipher.decrypt(ciphertext);

      expect(String.fromCharCodes(plaintext), 'hello over the wire');
    });
  });
}
