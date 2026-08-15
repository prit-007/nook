import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/updates/update_checker.dart';
import 'package:nook/features/updates/update_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

GithubRelease _release(String tag) => GithubRelease(
      tagName: tag,
      name: tag,
      htmlUrl: 'https://github.com/prit-007/nook/releases/tag/$tag',
      body: 'Notes for $tag',
      publishedAt: DateTime(2026, 8, 15),
      draft: false,
      prerelease: false,
    );

class _FakeChecker implements UpdateChecker {
  _FakeChecker(this.release);

  GithubRelease? release;
  int calls = 0;

  @override
  Future<GithubRelease?> fetchLatestRelease({
    String owner = UpdateChecker.defaultOwner,
    String repo = UpdateChecker.defaultRepo,
  }) async {
    calls++;
    return release;
  }
}

class _ThrowingChecker implements UpdateChecker {
  @override
  Future<GithubRelease?> fetchLatestRelease({
    String owner = UpdateChecker.defaultOwner,
    String repo = UpdateChecker.defaultRepo,
  }) async {
    throw const UpdateCheckException('boom');
  }
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'nook',
      packageName: 'nook',
      version: '0.8.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
    SharedPreferences.setMockInitialValues({
      'update_last_checked_at': DateTime.now().millisecondsSinceEpoch,
    });
  });

  test('reports an available update when a newer release exists', () async {
    final container = ProviderContainer(
      overrides: [
        updateCheckerProvider
            .overrideWithValue(_FakeChecker(_release('v0.9.0'))),
      ],
    );
    addTearDown(container.dispose);

    final status =
        await container.read(updateStatusProvider.notifier).check(force: true);

    expect(status.hasUpdate, isTrue);
    expect(status.checking, isFalse);
    expect(status.hasError, isFalse);
    expect(status.dismissed, isFalse);
    expect(status.available!.latestVersion.raw, 'v0.9.0');
    expect(status.available!.currentVersion.raw, '0.8.0');
  });

  test('reports up to date when latest equals the running version', () async {
    final container = ProviderContainer(
      overrides: [
        updateCheckerProvider
            .overrideWithValue(_FakeChecker(_release('v0.8.0'))),
      ],
    );
    addTearDown(container.dispose);

    final status =
        await container.read(updateStatusProvider.notifier).check(force: true);

    expect(status.hasUpdate, isFalse);
    expect(status.hasError, isFalse);
    expect(status.latestChecked!.raw, 'v0.8.0');
  });

  test('reports up to date when no releases exist', () async {
    final container = ProviderContainer(
      overrides: [
        updateCheckerProvider.overrideWithValue(_FakeChecker(null)),
      ],
    );
    addTearDown(container.dispose);

    final status =
        await container.read(updateStatusProvider.notifier).check(force: true);

    expect(status.hasUpdate, isFalse);
    expect(status.latestChecked, isNull);
    expect(status.hasError, isFalse);
  });

  test('surfaces a failed check', () async {
    final container = ProviderContainer(
      overrides: [
        updateCheckerProvider.overrideWithValue(_ThrowingChecker()),
      ],
    );
    addTearDown(container.dispose);

    final status =
        await container.read(updateStatusProvider.notifier).check(force: true);

    expect(status.hasError, isTrue);
    expect(status.hasUpdate, isFalse);
    expect(status.checking, isFalse);
  });

  test('dismiss persists per version and clears for a newer release', () async {
    final checker = _FakeChecker(_release('v0.9.0'));
    final container = ProviderContainer(
      overrides: [updateCheckerProvider.overrideWithValue(checker)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(updateStatusProvider.notifier);
    await notifier.check(force: true);
    expect(container.read(updateStatusProvider).hasUpdate, isTrue);

    await notifier.dismiss();
    expect(container.read(updateStatusProvider).hasUpdate, isFalse);
    expect(container.read(updateStatusProvider).dismissed, isTrue);

    // A fresh container over the same storage honours the dismissal...
    final container2 = ProviderContainer(
      overrides: [updateCheckerProvider.overrideWithValue(checker)],
    );
    addTearDown(container2.dispose);
    final status2 =
        await container2.read(updateStatusProvider.notifier).check(force: true);
    expect(status2.hasUpdate, isFalse);
    expect(status2.dismissed, isTrue);

    // ...until a newer release replaces the dismissed one.
    checker.release = _release('v0.10.0');
    final status3 =
        await container2.read(updateStatusProvider.notifier).check(force: true);
    expect(status3.hasUpdate, isTrue);
    expect(status3.dismissed, isFalse);
  });
}
