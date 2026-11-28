import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/security/dek_manager.dart';
import 'package:nook/core/security/recovery_key_provider.dart';
import 'package:nook/core/security/secure_kv_store.dart';
import 'package:nook/features/security/vault_db_gate_screen.dart';

class _MemStore implements SecureKeyValueStore {
  final Map<String, String> _map = {};

  @override
  Future<void> delete(String key) async => _map.remove(key);

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;
}

void main() {
  testWidgets('VaultDbGateScreen rejects wrong password and unlocks with right',
      (tester) async {
    final store = _MemStore();
    await store.write(DekManager.dbEncryptionKeyStorageKey, 'test-dek');
    final dekManager = DekManager(
      store: store,
      iterations: 100,
      argon2Memory: 1024,
      argon2Iterations: 1,
    );
    await tester.runAsync(() async {
      await dekManager.wrapDekWithPassword('vault-secret');
    });

    String? unlockedDek;

    await tester.pumpWidget(
      MaterialApp(
        home: VaultDbGateScreen(
          dekManager: dekManager,
          hasRecoveryKey: false,
          onUnlocked: (dek, _) async {
            unlockedDek = dek;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('Unlock Vault'));
    await tester.pump();
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Incorrect vault password').evaluate().isNotEmpty) break;
    }
    expect(find.text('Incorrect vault password'), findsOneWidget);
    expect(unlockedDek, isNull);

    await tester.enterText(find.byType(TextField), 'vault-secret');
    await tester.tap(find.text('Unlock Vault'));
    await tester.pump();
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (unlockedDek != null) break;
    }
    expect(unlockedDek, 'test-dek');
  });

  testWidgets('VaultDbGateScreen supports 24-word recovery key fallback',
      (tester) async {
    final store = _MemStore();
    await store.write(DekManager.dbEncryptionKeyStorageKey, 'recovered-dek');
    final dekManager = DekManager(
      store: store,
      iterations: 100,
      argon2Memory: 1024,
      argon2Iterations: 1,
    );
    final words = generateRecoveryKey();
    await tester.runAsync(() async {
      await dekManager.wrapDekWithPassword('pw', recoveryWords: words);
    });

    String? unlockedDek;

    await tester.pumpWidget(
      MaterialApp(
        home: VaultDbGateScreen(
          dekManager: dekManager,
          hasRecoveryKey: true,
          onUnlocked: (dek, _) async {
            unlockedDek = dek;
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Use 24-word recovery key'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), words.join(' '));
    await tester.tap(find.text('Unlock Vault'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(unlockedDek, 'recovered-dek');
  });
}
