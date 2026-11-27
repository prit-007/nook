import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/vault_password_provider.dart';
import 'package:nook/core/security/dek_manager.dart';
import 'package:nook/core/security/recovery_key_provider.dart';
import 'package:nook/core/security/secure_kv_store.dart';
import 'package:nook/features/onboarding/onboarding_screen.dart';
import 'package:nook/features/security/vault_password_dialog.dart';
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

  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: OnboardingScreen(),
      ),
    );
  }

  testWidgets('renders headline', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Your notes. Your device. Yours.'), findsOneWidget);
  });

  testWidgets('renders subtext', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(
      find.text('No account. No cloud. No one else reads your notes.'),
      findsOneWidget,
    );
  });

  testWidgets('renders Continue button on first page', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('renders illustration icon', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedNotebook01),
        findsOneWidget);
  });

  testWidgets('renders page view', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('Continue advances to note-types page', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Three ways to capture'), findsOneWidget);
  });

  testWidgets('skip button exists and is visible', (tester) async {
    await tester.pumpWidget(buildScreen());
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('shows seed color picker on vibe page', (tester) async {
    await tester.pumpWidget(buildScreen());
    // Page 1 → Page 2 (note types) → Page 3 (vibe)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Pick your vibe'), findsOneWidget);
  });

  testWidgets('shows protect vault page with setup and skip options',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    // Page 1 → Page 2 → Page 3 → Page 4 (Protect Vault)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Protect your vault'), findsOneWidget);
    expect(find.text('Set vault password & recovery key'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('fifth page shows Get Started after advancing past vault page',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    // 0: Welcome -> 1: Note Types
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // 1 -> 2: Vibe
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    // 2 -> 3: Protect Vault
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Skip vault setup to final page
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text("You're all set!"), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    // Skip button should be invisible on the final page
    final opacityFinder = find.ancestor(
      of: find.text('Skip'),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(opacityFinder).opacity, 0.0);
  });

  testWidgets('dot indicators exist', (tester) async {
    await tester.pumpWidget(buildScreen());
    // 5 dot indicators via AnimatedContainer (one per page)
    expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(5));
  });

  testWidgets('onboarding wires recovery key into DEK wrapping',
      (tester) async {
    final store = _InMemoryKvStore();
    await store.write(DekManager.dbEncryptionKeyStorageKey, 'onboarding-dek');
    final dekManager = DekManager(store: store, iterations: 100);
    final vaultProvider = VaultPasswordProvider(
      store: store,
      dekManager: dekManager,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultPasswordProvider.overrideWith((ref) => vaultProvider),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dynamic state = tester.state(find.byType(OnboardingScreen));
    final words = generateRecoveryKey();
    await state.wrapDekWithPassword(
      password: 'test-vault-password',
      recoveryWords: words,
    );

    expect(vaultProvider.enabled, isTrue);
    expect(await dekManager.isWrapped(), isTrue);
    expect(
      await dekManager.unwrapDekWithPassword('test-vault-password'),
      'onboarding-dek',
    );
    expect(await dekManager.unwrapDekWithRecoveryKey(words), 'onboarding-dek');
  });

  testWidgets(
      'onboarding _ProtectVaultPage onSetupVault wires wrapDekWithPassword callback',
      (tester) async {
    final store = _InMemoryKvStore();
    await store.write(DekManager.dbEncryptionKeyStorageKey, 'ui-dek-wrap');
    final dekManager = DekManager(store: store, iterations: 100);
    final vaultProvider = VaultPasswordProvider(
      store: store,
      dekManager: dekManager,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultPasswordProvider.overrideWith((ref) => vaultProvider),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to page 3 (_ProtectVaultPage)
    final pageView = tester.widget<PageView>(find.byType(PageView));
    pageView.controller!.jumpToPage(3);
    await tester.pumpAndSettle();

    expect(find.text('Protect your vault'), findsOneWidget);
    expect(find.text('Set vault password & recovery key'), findsOneWidget);

    // Tap setup button which opens VaultPasswordSetDialog wired to wrapDekWithPassword
    await tester.tap(find.text('Set vault password & recovery key'));
    await tester.pumpAndSettle();

    expect(find.byType(VaultPasswordSetDialog), findsOneWidget);
  });
}
