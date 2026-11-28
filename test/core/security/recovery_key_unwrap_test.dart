import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/security/dek_manager.dart';
import 'package:nook/core/security/recovery_key_provider.dart';
import 'package:nook/core/security/secure_kv_store.dart';

void main() {
  test('Recovery key unwraps DEK alone; wrong words or missing key fail',
      () async {
    final store = InMemorySecureKeyValueStore();
    await store.write(DekManager.dbEncryptionKeyStorageKey, 'vault-dek-123');
    final dekManager = DekManager(
      store: store,
      iterations: 100,
      argon2Memory: 1024,
      argon2Iterations: 1,
    );

    final shownWords = generateRecoveryKey();
    final otherWords = generateRecoveryKey();

    await dekManager.wrapDekWithPassword(
      'strong-vault-pass',
      recoveryWords: shownWords,
    );

    // Recovery key is NOT stored in plaintext anywhere in store.
    for (final v in store.debugData.values) {
      expect(v, isNot(contains(shownWords.first)));
    }

    // Shown words unwrap DEK; mismatched words fail.
    expect(
      await dekManager.unwrapDekWithRecoveryKey(shownWords),
      'vault-dek-123',
    );
    expect(
      await dekManager.unwrapDekWithRecoveryKey(otherWords),
      isNull,
    );
  });
}
