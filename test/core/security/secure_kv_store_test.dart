import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/security/dek_manager.dart';
import 'package:nook/core/security/secure_kv_store.dart';
import 'package:nook/data/database.dart';

void main() {
  group('Biometric-bound keystore & vault DB gate (Phase 1.3)', () {
    test('FlutterSecureKeyValueStore uses hardened platform security options',
        () {
      const store = FlutterSecureKeyValueStore();
      expect(
        store.storage.iOptions.accessibility,
        KeychainAccessibility.unlocked_this_device,
      );
      expect(
        store.storage.mOptions.accessibility,
        KeychainAccessibility.unlocked_this_device,
      );
    });

    test('openEncryptedDatabase refuses to open wrapped DB without overrideKey',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final memStore = InMemorySecureKeyValueStore();
      await memStore.write(DekManager.dbEncryptionKeyStorageKey, 'secret-dek');
      final dekManager = DekManager(
        store: memStore,
        iterations: 100,
        argon2Memory: 1024,
        argon2Iterations: 1,
      );
      await dekManager.wrapDekWithPassword('pw');

      expect(
        () => openEncryptedDatabase(store: memStore),
        throwsA(isA<VaultLockedException>()),
      );
    });
  });
}
