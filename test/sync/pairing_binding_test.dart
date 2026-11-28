import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/crypto/sync_cipher.dart';

void main() {
  group('Key-bound pairing code', () {
    test('produces deterministic 6-digit code and detects key substitution',
        () {
      final localKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      final remoteKey =
          Uint8List.fromList(List<int>.generate(32, (i) => i + 50));
      final mitmKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 99));
      final nonce = Uint8List.fromList(List<int>.generate(16, (i) => i * 3));
      final otherNonce =
          Uint8List.fromList(List<int>.generate(16, (i) => i * 5 + 1));

      final code1 = SyncCipher.deriveKeyBoundPairingCode(
        localPublicKey: localKey,
        remotePublicKey: remoteKey,
        nonce: nonce,
      );
      final code2 = SyncCipher.deriveKeyBoundPairingCode(
        localPublicKey: localKey,
        remotePublicKey: remoteKey,
        nonce: nonce,
      );
      expect(code1, equals(code2));
      expect(RegExp(r'^\d{6}$').hasMatch(code1), isTrue);

      // Substituting remote public key (MITM) changes the pairing code.
      final mitmCode = SyncCipher.deriveKeyBoundPairingCode(
        localPublicKey: localKey,
        remotePublicKey: mitmKey,
        nonce: nonce,
      );
      expect(mitmCode, isNot(equals(code1)));

      // Changing nonce also changes the pairing code.
      final newNonceCode = SyncCipher.deriveKeyBoundPairingCode(
        localPublicKey: localKey,
        remotePublicKey: remoteKey,
        nonce: otherNonce,
      );
      expect(newNonceCode, isNot(equals(code1)));
    });
  });
}
