import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/security/dek_manager.dart';
import 'package:nook/core/security/kdf.dart';
import 'package:nook/core/security/secure_kv_store.dart';

void main() {
  group('Argon2id KDF (v2)', () {
    test('argon2idHash produces v2\$argon2id\$... format and verifies',
        () async {
      final hash = await argon2idHash(
        password: 'correct-horse-battery-staple',
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );

      expect(hash, startsWith('v2\$argon2id\$m=1024,t=1,p=1\$'));
      final parts = hash.split('\$');
      expect(parts.length, 5);
      expect(parts[0], 'v2');
      expect(parts[1], 'argon2id');
      expect(parts[2], 'm=1024,t=1,p=1');
      expect(parts[3], isNotEmpty);
      expect(parts[4], isNotEmpty);

      expect(
        await argon2idVerify(
          password: 'correct-horse-battery-staple',
          storedHash: hash,
        ),
        isTrue,
      );
      expect(
        await argon2idVerify(
          password: 'wrong-password',
          storedHash: hash,
        ),
        isFalse,
      );
    });

    test('argon2idDeriveBytes is deterministic for same inputs', () async {
      final salt = utf8.encode('fixed-salt-bytes');
      final a = await argon2idDeriveBytes(
        password: 'secret',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
        keyLength: 32,
      );
      final b = await argon2idDeriveBytes(
        password: 'secret',
        salt: salt,
        memory: 1024,
        iterations: 1,
        parallelism: 1,
        keyLength: 32,
      );

      expect(a, hasLength(32));
      expect(a, equals(b));
    });

    test('kdfVerify handles both v2 Argon2id and legacy PBKDF2 hashes',
        () async {
      final v2Hash = await argon2idHash(
        password: 'my-secret',
        memory: 1024,
        iterations: 1,
        parallelism: 1,
      );
      final legacyHash = pbkdf2Hash(
        password: 'my-secret',
        iterations: 100,
      );

      expect(
          await kdfVerify(password: 'my-secret', storedHash: v2Hash), isTrue);
      expect(await kdfVerify(password: 'wrong', storedHash: v2Hash), isFalse);
      expect(
        await kdfVerify(password: 'my-secret', storedHash: legacyHash),
        isTrue,
      );
      expect(
        await kdfVerify(password: 'wrong', storedHash: legacyHash),
        isFalse,
      );
      expect(isLegacyPbkdf2Hash(legacyHash), isTrue);
      expect(isLegacyPbkdf2Hash(v2Hash), isFalse);
    });
  });

  group('DekManager KDF migration (PBKDF2 -> Argon2id)', () {
    test('new wrapDekWithPassword uses v2\$argon2id\$ format', () async {
      final store = InMemorySecureKeyValueStore();
      await store.write(DekManager.dbEncryptionKeyStorageKey, 'dek-v2-test');
      final manager = DekManager(
        store: store,
        iterations: 100,
        argon2Memory: 1024,
        argon2Iterations: 1,
        argon2Parallelism: 1,
      );

      await manager.wrapDekWithPassword('vault-pw');
      final raw = await store.read(DekManager.wrappedDekStorageKey);
      expect(raw, isNotNull);

      final envelope = jsonDecode(raw!) as Map<String, dynamic>;
      expect(envelope['v'], 2);
      expect(envelope['kdf'], startsWith('v2\$argon2id\$'));
      expect(
        await manager.unwrapDekWithPassword('vault-pw'),
        'dek-v2-test',
      );
      expect(await manager.unwrapDekWithPassword('wrong'), isNull);
    });

    test('migrates legacy v1 PBKDF2 wrapped DEK to v2 Argon2id on unwrap',
        () async {
      final store = InMemorySecureKeyValueStore();
      const dek = 'legacy-dek-to-migrate';
      final manager = DekManager(
        store: store,
        iterations: 100,
        argon2Memory: 1024,
        argon2Iterations: 1,
        argon2Parallelism: 1,
      );

      // Seed a legacy v1 PBKDF2-wrapped DEK envelope directly.
      final legacyEnvelope = await manager.encryptLegacyV1ForTest(
        dek: dek,
        password: 'legacy-password',
        iterations: 100,
      );
      await store.write(DekManager.wrappedDekStorageKey, legacyEnvelope);

      // Wrong password must fail and NOT migrate or corrupt the stored DEK.
      expect(await manager.unwrapDekWithPassword('wrong-password'), isNull);
      final stillLegacy =
          jsonDecode((await store.read(DekManager.wrappedDekStorageKey))!)
              as Map<String, dynamic>;
      expect(stillLegacy['v'], 1);

      // Correct password unwraps AND migrates to v2 Argon2id.
      final unwrapped = await manager.unwrapDekWithPassword('legacy-password');
      expect(unwrapped, dek);

      final migratedRaw = await store.read(DekManager.wrappedDekStorageKey);
      expect(migratedRaw, isNotNull);
      final migrated = jsonDecode(migratedRaw!) as Map<String, dynamic>;
      expect(migrated['v'], 2);
      expect(migrated['kdf'], startsWith('v2\$argon2id\$'));

      // Subsequent unwraps work with the migrated v2 envelope.
      expect(
        await manager.unwrapDekWithPassword('legacy-password'),
        dek,
      );
    });

    test(
        'interrupted migration rollback leaves stored DEK intact on write failure',
        () async {
      final baseStore = InMemorySecureKeyValueStore();
      final failingStore = _FailOnSecondWriteStore(baseStore);
      const dek = 'rollback-safe-dek';
      final manager = DekManager(
        store: failingStore,
        iterations: 100,
        argon2Memory: 1024,
        argon2Iterations: 1,
        argon2Parallelism: 1,
      );

      final legacyEnvelope = await manager.encryptLegacyV1ForTest(
        dek: dek,
        password: 'pw',
        iterations: 100,
      );
      // First write seeds the legacy envelope.
      await failingStore.write(DekManager.wrappedDekStorageKey, legacyEnvelope);
      failingStore.failNextWrite = true;

      // Unwrap still succeeds or returns DEK without corrupting stored envelope.
      final unwrapped = await manager.unwrapDekWithPassword('pw');
      expect(unwrapped, dek);

      // Stored envelope remains intact (still valid legacy v1).
      final storedAfter = await baseStore.read(DekManager.wrappedDekStorageKey);
      expect(storedAfter, legacyEnvelope);

      // Subsequent unwrap with a healthy store succeeds and migrates cleanly.
      failingStore.failNextWrite = false;
      expect(await manager.unwrapDekWithPassword('pw'), dek);
      final migrated =
          jsonDecode((await baseStore.read(DekManager.wrappedDekStorageKey))!)
              as Map<String, dynamic>;
      expect(migrated['v'], 2);
    });
  });
}

class _FailOnSecondWriteStore implements SecureKeyValueStore {
  _FailOnSecondWriteStore(this._inner);

  final InMemorySecureKeyValueStore _inner;
  bool failNextWrite = false;

  @override
  Future<void> delete(String key) => _inner.delete(key);

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<void> write(String key, String value) async {
    if (failNextWrite) {
      throw StateError('Simulated write failure during migration');
    }
    await _inner.write(key, value);
  }
}
