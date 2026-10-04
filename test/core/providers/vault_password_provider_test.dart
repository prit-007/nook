import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/vault_password_provider.dart';
import 'package:nook/core/security/kdf.dart';
import 'package:nook/core/security/secure_kv_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultPasswordProvider', () {
    late VaultPasswordProvider vault;
    late InMemorySecureKeyValueStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = InMemorySecureKeyValueStore();
      vault = VaultPasswordProvider(store: store);
    });

    test('disabled and locked by default', () {
      expect(vault.enabled, isFalse);
      expect(vault.isUnlocked, isFalse);
    });

    test('setPassword enables and unlocks', () async {
      await vault.setPassword('correct horse');
      expect(vault.enabled, isTrue);
      expect(vault.isUnlocked, isTrue);
      expect(store.debugData.containsKey('vault_password_hash'), isTrue);
    });

    test('setPassword rejects empty password', () async {
      expect(() => vault.setPassword(''), throwsArgumentError);
    });

    test('unlock accepts correct password after relock', () async {
      await vault.setPassword('s3cret');
      vault.resetAuth();
      expect(vault.isUnlocked, isFalse);

      final ok = await vault.unlock('s3cret');
      expect(ok, isTrue);
      expect(vault.isUnlocked, isTrue);
    });

    test('unlock rejects wrong password', () async {
      await vault.setPassword('s3cret');
      vault.resetAuth();
      final ok = await vault.unlock('wrong');
      expect(ok, isFalse);
      expect(vault.isUnlocked, isFalse);
    });

    test('unlock fails when no password is stored', () async {
      final ok = await vault.unlock('anything');
      expect(ok, isFalse);
    });

    test('clearPassword disables and locks', () async {
      await vault.setPassword('s3cret');
      await vault.clearPassword();
      expect(vault.enabled, isFalse);
      expect(vault.isUnlocked, isFalse);
      expect(store.debugData.containsKey('vault_password_hash'), isFalse);
      expect(await vault.unlock('s3cret'), isFalse);
    });

    test('hash format uses shared KDF (salt:iterations:derived)', () {
      final hash = pbkdf2Hash(password: 'abc');
      expect(hash.split(':'), hasLength(3));
      expect(pbkdf2Verify(password: 'abc', storedHash: hash), isTrue);
    });

    test('load reads enabled flag from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'vault_password_enabled': true});
      final loaded = await VaultPasswordProvider.load(store: store);
      expect(loaded.enabled, isTrue);
      expect(loaded.isUnlocked, isFalse);
    });
  });
}
