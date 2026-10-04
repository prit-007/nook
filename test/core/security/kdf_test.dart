import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/security/kdf.dart';

void main() {
  group('pbkdf2Hash / pbkdf2Verify', () {
    test('hash format is salt:iterations:derived (3 colon-separated parts)',
        () {
      final hash = pbkdf2Hash(password: '123456');
      final parts = hash.split(':');
      expect(parts, hasLength(3));
      expect(int.tryParse(parts[1]), defaultPbkdf2Iterations);
      expect(parts[0], isNotEmpty);
      expect(parts[2], isNotEmpty);
    });

    test('verify accepts the correct password', () {
      final hash = pbkdf2Hash(password: 'hunter2');
      expect(pbkdf2Verify(password: 'hunter2', storedHash: hash), isTrue);
    });

    test('verify rejects a wrong password', () {
      final hash = pbkdf2Hash(password: 'hunter2');
      expect(pbkdf2Verify(password: 'wrong', storedHash: hash), isFalse);
    });

    test('same password + salt + iterations is deterministic', () {
      const salt = 'c2FsdHNhbHRzYWx0c2FsdA';
      final a = pbkdf2Hash(
        password: '123456',
        saltBase64: salt,
        iterations: 1000,
      );
      final b = pbkdf2Hash(
        password: '123456',
        saltBase64: salt,
        iterations: 1000,
      );
      expect(a, b);
    });

    test('different salts produce different hashes', () {
      final a =
          pbkdf2Hash(password: '123456', saltBase64: 'YWJjZGVmZ2hpamtsbW5vcA');
      final b =
          pbkdf2Hash(password: '123456', saltBase64: 'cG9yc3R1dXZ3eHl6MDEyMzQ');
      expect(a, isNot(b));
    });

    test('different passwords produce different hashes', () {
      const salt = 'c2FsdHNhbHRzYWx0c2FsdA';
      final a =
          pbkdf2Hash(password: '111111', saltBase64: salt, iterations: 1000);
      final b =
          pbkdf2Hash(password: '222222', saltBase64: salt, iterations: 1000);
      expect(a, isNot(b));
    });

    test('verify reads iterations from the stored hash', () {
      final hash = pbkdf2Hash(
        password: 'abc',
        saltBase64: 'c2FsdHNhbHRzYWx0c2FsdA',
        iterations: 500,
      );
      expect(hash.split(':')[1], '500');
      expect(pbkdf2Verify(password: 'abc', storedHash: hash), isTrue);
    });

    test('legacy salt:hex format is rejected (mismatch, not crash)', () {
      // Old SHA-256 format had exactly 2 colon-separated parts.
      const legacy = 'c2FsdA:abcdef0123456789';
      expect(pbkdf2Verify(password: '123456', storedHash: legacy), isFalse);
    });

    test('malformed hashes are rejected', () {
      expect(pbkdf2Verify(password: 'x', storedHash: ''), isFalse);
      expect(pbkdf2Verify(password: 'x', storedHash: 'onlyone'), isFalse);
      expect(
        pbkdf2Verify(password: 'x', storedHash: 'a:notanint:deadbeef'),
        isFalse,
      );
      expect(
        pbkdf2Verify(password: 'x', storedHash: 'a:0:deadbeef'),
        isFalse,
      );
    });

    test('generateSalt returns unique base64url strings', () {
      final s1 = generateSalt();
      final s2 = generateSalt();
      expect(s1, isNot(s2));
      // base64Url may include '=' padding for some byte lengths.
      expect(s1, matches(RegExp(r'^[A-Za-z0-9_-]+=*$')));
    });
  });

  group('pbkdf2DeriveBytes', () {
    test('derives the requested number of bytes', () {
      final key = pbkdf2DeriveBytes(
        password: 'password',
        salt: 'salt'.codeUnits,
        iterations: 1,
        keyLength: 32,
      );
      expect(key, hasLength(32));
    });

    test('matches RFC 6070-style SHA-256 vector (password/salt, c=1)', () {
      // Published PBKDF2-HMAC-SHA256 test vector:
      // P="password", S="salt", c=1, dkLen=32
      final key = pbkdf2DeriveBytes(
        password: 'password',
        salt: 'salt'.codeUnits,
        iterations: 1,
        keyLength: 32,
      );
      final hex = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      expect(
        hex,
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('same inputs are deterministic', () {
      List<int> derive() => pbkdf2DeriveBytes(
            password: 'secret',
            salt: [1, 2, 3, 4],
            iterations: 100,
            keyLength: 16,
          );
      expect(derive(), derive());
    });
  });
}
