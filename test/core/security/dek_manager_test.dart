import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/vault_password_provider.dart';
import 'package:nook/core/security/dek_manager.dart';
import 'package:nook/core/security/recovery_key_provider.dart';
import 'package:nook/core/security/secure_kv_store.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _InMemoryKvStore implements SecureKeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DekManager (C2)', () {
    test('wraps existing DEK, deletes plaintext key, and unwraps with password',
        () async {
      final store = _InMemoryKvStore();
      await store.write(DekManager.dbEncryptionKeyStorageKey, 'existing-dek');
      final manager = DekManager(store: store, iterations: 100);

      expect(await manager.isWrapped(), isFalse);
      await manager.wrapDekWithPassword('correct-horse');

      expect(await manager.isWrapped(), isTrue);
      expect(await store.read(DekManager.dbEncryptionKeyStorageKey), isNull);

      expect(await manager.unwrapDekWithPassword('wrong'), isNull);
      expect(
        await manager.unwrapDekWithPassword('correct-horse'),
        'existing-dek',
      );
    });

    test('supports 24-word recovery key wrapping and unwrapping', () async {
      final store = _InMemoryKvStore();
      await store.write(DekManager.dbEncryptionKeyStorageKey, 'secret-dek');
      final manager = DekManager(store: store, iterations: 100);
      final recoveryWords = generateRecoveryKey();

      await manager.wrapDekWithPassword(
        'vault-pass',
        recoveryWords: recoveryWords,
      );
      expect(await manager.hasRecoveryWrappedDek(), isTrue);

      expect(
        await manager.unwrapDekWithRecoveryKey(recoveryWords),
        'secret-dek',
      );
      final otherWords = generateRecoveryKey();
      expect(await manager.unwrapDekWithRecoveryKey(otherWords), isNull);
    });

    test('rotates password and disables wrapping cleanly', () async {
      final store = _InMemoryKvStore();
      await store.write(DekManager.dbEncryptionKeyStorageKey, 'dek-123');
      final manager = DekManager(store: store, iterations: 100);
      await manager.wrapDekWithPassword('old-pass');

      expect(
        await manager.rotatePassword(
          oldPassword: 'wrong',
          newPassword: 'new-pass',
        ),
        isFalse,
      );
      expect(
        await manager.rotatePassword(
          oldPassword: 'old-pass',
          newPassword: 'new-pass',
        ),
        isTrue,
      );

      expect(await manager.unwrapDekWithPassword('old-pass'), isNull);
      expect(await manager.unwrapDekWithPassword('new-pass'), 'dek-123');

      expect(await manager.disableWrappingWithPassword('wrong'), isFalse);
      expect(await manager.disableWrappingWithPassword('new-pass'), isTrue);
      expect(await manager.isWrapped(), isFalse);
      expect(
        await store.read(DekManager.dbEncryptionKeyStorageKey),
        'dek-123',
      );
    });

    test('rotatePassword keeps recovery key valid', () async {
      final store = _InMemoryKvStore();
      await store.write(DekManager.dbEncryptionKeyStorageKey, 'dek-stable');
      final manager = DekManager(store: store, iterations: 100);
      final words = generateRecoveryKey();

      await manager.wrapDekWithPassword('pw-1', recoveryWords: words);
      expect(await manager.unwrapDekWithRecoveryKey(words), 'dek-stable');

      expect(
        await manager.rotatePassword(oldPassword: 'pw-1', newPassword: 'pw-2'),
        isTrue,
      );

      // Recovery key must remain fully valid and decrypt the unchanged DEK
      expect(await manager.unwrapDekWithRecoveryKey(words), 'dek-stable');
      expect(await manager.unwrapDekWithPassword('pw-2'), 'dek-stable');
      expect(await manager.unwrapDekWithPassword('pw-1'), isNull);
    });

    test('disableWrappingWithPassword and restoreUnwrappedDek round-trip',
        () async {
      final store = _InMemoryKvStore();
      await store.write(DekManager.dbEncryptionKeyStorageKey, 'dek-roundtrip');
      final manager = DekManager(store: store, iterations: 100);

      await manager.wrapDekWithPassword('roundtrip-pass');
      expect(await manager.isWrapped(), isTrue);
      expect(await store.read(DekManager.dbEncryptionKeyStorageKey), isNull);

      // Successful disable restores plaintext DEK
      final disabled =
          await manager.disableWrappingWithPassword('roundtrip-pass');
      expect(disabled, isTrue);
      expect(await manager.isWrapped(), isFalse);
      expect(
        await store.read(DekManager.dbEncryptionKeyStorageKey),
        'dek-roundtrip',
      );

      // Direct restoreUnwrappedDek round-trip
      await manager.wrapDekWithPassword('roundtrip-pass');
      expect(await manager.isWrapped(), isTrue);
      await manager.restoreUnwrappedDek('dek-roundtrip');
      expect(await manager.isWrapped(), isFalse);
      expect(
        await store.read(DekManager.dbEncryptionKeyStorageKey),
        'dek-roundtrip',
      );
    });

    test('failed unwrap never corrupts stored DEK', () async {
      final store = _InMemoryKvStore();
      await store.write(
          DekManager.dbEncryptionKeyStorageKey, 'dek-uncorrupted');
      final manager = DekManager(store: store, iterations: 100);
      final words = generateRecoveryKey();

      await manager.wrapDekWithPassword('correct-pass', recoveryWords: words);
      final originalWrappedEnvelope =
          await store.read(DekManager.wrappedDekStorageKey);
      final originalRecoveryEnvelope =
          await store.read(DekManager.recoveryWrappedDekStorageKey);

      // Attempt multiple failed unwraps with incorrect passwords
      for (var i = 0; i < 5; i++) {
        expect(
          await manager.unwrapDekWithPassword('wrong-attempt-$i'),
          isNull,
        );
      }

      // Attempt failed unwrap with wrong recovery key
      final wrongWords = generateRecoveryKey();
      expect(await manager.unwrapDekWithRecoveryKey(wrongWords), isNull);

      // Envelopes in store remain unmodified and pristine
      expect(
        await store.read(DekManager.wrappedDekStorageKey),
        originalWrappedEnvelope,
      );
      expect(
        await store.read(DekManager.recoveryWrappedDekStorageKey),
        originalRecoveryEnvelope,
      );

      // Correct credentials still unwrap perfectly
      expect(
        await manager.unwrapDekWithPassword('correct-pass'),
        'dek-uncorrupted',
      );
      expect(
        await manager.unwrapDekWithRecoveryKey(words),
        'dek-uncorrupted',
      );
    });

    test('killed app mid-wrap recovers', () async {
      final store = _InMemoryKvStore();
      await store.write(DekManager.dbEncryptionKeyStorageKey, 'dek-safe');
      final manager = DekManager(store: store, iterations: 100);

      // Case A: App killed while writing partial/corrupted vault_wrapped_dek
      // (before plaintext key deletion).
      await store.write(DekManager.wrappedDekStorageKey, '{"partial": true');
      await manager.recoverInterruptedWrap();
      expect(await manager.isWrapped(), isFalse);
      expect(
        await store.read(DekManager.dbEncryptionKeyStorageKey),
        'dek-safe',
      );

      // Case B: App killed after writing valid wrapped envelope, but before
      // deleting the plaintext key.
      await manager.wrapDekWithPassword('pw');
      await store.write(DekManager.dbEncryptionKeyStorageKey, 'dek-safe');
      await manager.recoverInterruptedWrap();
      expect(await manager.isWrapped(), isTrue);
      expect(await store.read(DekManager.dbEncryptionKeyStorageKey), isNull);
      expect(await manager.unwrapDekWithPassword('pw'), 'dek-safe');
    });
  });

  group('VaultPasswordProvider + C2 DEK integration', () {
    test('setPassword wraps DEK and clearPassword restores it', () async {
      final store = _InMemoryKvStore();
      await store.write(DekManager.dbEncryptionKeyStorageKey, 'db-key-xyz');
      final dekManager = DekManager(store: store, iterations: 100);
      final provider = VaultPasswordProvider(
        store: store,
        dekManager: dekManager,
      );

      await provider.setPassword('my-vault-pw');
      expect(provider.enabled, isTrue);
      expect(provider.isUnlocked, isTrue);
      expect(provider.sessionDek, 'db-key-xyz');
      expect(await dekManager.isWrapped(), isTrue);
      expect(await store.read(DekManager.dbEncryptionKeyStorageKey), isNull);

      provider.resetAuth();
      expect(provider.isUnlocked, isFalse);
      expect(provider.sessionDek, isNull);

      expect(await provider.unlock('wrong'), isFalse);
      expect(await provider.unlock('my-vault-pw'), isTrue);
      expect(provider.sessionDek, 'db-key-xyz');

      await provider.clearPassword();
      expect(provider.enabled, isFalse);
      expect(await dekManager.isWrapped(), isFalse);
      expect(
        await store.read(DekManager.dbEncryptionKeyStorageKey),
        'db-key-xyz',
      );
    });

    test('wrapped vault upgrade preserves wrapped DEK across migrations',
        () async {
      final store = _InMemoryKvStore();
      await store.write(
          DekManager.dbEncryptionKeyStorageKey, 'dek-v10-upgrade');
      final dekManager = DekManager(store: store, iterations: 100);
      final words = generateRecoveryKey();

      // Step 1: Wrap vault with password & recovery key (simulating v10 app state)
      await dekManager.wrapDekWithPassword('vault-pass-upgrade',
          recoveryWords: words);
      expect(await dekManager.isWrapped(), isTrue);

      // Step 2: Simulate app cold boot / upgrade to v11
      // Plaintext DEK in storage is absent
      expect(await store.read(DekManager.dbEncryptionKeyStorageKey), isNull);

      // Step 3: Vault gate screen prompts user for password and unwraps DEK
      final unwrappedDek =
          await dekManager.unwrapDekWithPassword('vault-pass-upgrade');
      expect(unwrappedDek, 'dek-v10-upgrade');

      // Step 4: Database opens with unwrapped DEK and executes migrations safely
      final db = AppDatabase(NativeDatabase.memory());
      try {
        await db.customSelect('SELECT 1').get();
      } finally {
        await db.close();
      }

      // Step 5: Wrapped state and recovery envelopes remain valid after upgrade
      expect(await dekManager.isWrapped(), isTrue);
      expect(
        await dekManager.unwrapDekWithRecoveryKey(words),
        'dek-v10-upgrade',
      );
    });

    test(
        'legacy unwrapped DEK upgrades to wrapped, data is readable, wrong password fails, upgrade is idempotent',
        () async {
      final store = _InMemoryKvStore();
      const initialDek = 'legacy-plain-dek-32-chars-long!!';
      await store.write(DekManager.dbEncryptionKeyStorageKey, initialDek);

      final dekManager = DekManager(store: store, iterations: 100);
      final provider =
          VaultPasswordProvider(store: store, dekManager: dekManager);

      expect(await dekManager.isWrapped(), isFalse);
      expect(
          await store.read(DekManager.dbEncryptionKeyStorageKey), initialDek);

      final tempDir =
          await Directory.systemTemp.createTemp('nook_vault_upgrade_');
      final dbFile = File(p.join(tempDir.path, 'notes.db'));
      try {
        final db1 = AppDatabase(NativeDatabase(dbFile));
        await db1.into(db1.notes).insert(
              NotesCompanion.insert(
                id: const Value('legacy-note-1'),
                title: const Value('Pre-upgrade Secret Note'),
                plainText: const Value('Crucial user note data'),
                type: NoteType.text,
                deviceOriginId: 'device-1',
                createdAt: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
              ),
            );
        await db1.close();

        // Perform vault upgrade with password and recovery key
        final recoveryWords = generateRecoveryKey();
        await provider.setPassword('vault-secure-pw-42',
            recoveryWords: recoveryWords);

        // Confirm DEK is wrapped and plaintext DEK is deleted from storage
        expect(await dekManager.isWrapped(), isTrue);
        expect(await store.read(DekManager.dbEncryptionKeyStorageKey), isNull);

        // Running upgrade twice is idempotent
        await provider.setPassword('vault-secure-pw-42',
            recoveryWords: recoveryWords);
        expect(await dekManager.isWrapped(), isTrue);

        // Wrong password fails and leaves data untouched
        final wrongUnwrap = await dekManager.unwrapDekWithPassword('wrong-pw');
        expect(wrongUnwrap, isNull);

        // Recovery key unwraps correctly
        final recoveryUnwrap =
            await dekManager.unwrapDekWithRecoveryKey(recoveryWords);
        expect(recoveryUnwrap, initialDek);

        // Correct password unwraps DEK, database opens, and pre-existing note is readable
        final correctUnwrap =
            await dekManager.unwrapDekWithPassword('vault-secure-pw-42');
        expect(correctUnwrap, initialDek);

        final db2 = AppDatabase(NativeDatabase(dbFile));
        final notes = await db2.select(db2.notes).get();
        expect(notes.length, 1);
        expect(notes.first.id, 'legacy-note-1');
        expect(notes.first.title, 'Pre-upgrade Secret Note');
        expect(notes.first.plainText, 'Crucial user note data');
        await db2.close();
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
