import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/updates/update_checker.dart';
import 'package:nook/features/updates/update_provider.dart';
import 'package:nook/features/updates/widgets/update_banner.dart';
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

  final GithubRelease? release;

  @override
  Future<GithubRelease?> fetchLatestRelease({
    String owner = UpdateChecker.defaultOwner,
    String repo = UpdateChecker.defaultRepo,
  }) async {
    return release;
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

  testWidgets('hidden when no update is available', (tester) async {
    final container = ProviderContainer(
      overrides: [
        updateCheckerProvider
            .overrideWithValue(_FakeChecker(_release('v0.8.0'))),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: UpdateBanner())),
      ),
    );

    expect(find.text('Update available'), findsNothing);
    expect(find.text('Later'), findsNothing);
  });

  testWidgets('shows the newer version and dismisses on Later', (tester) async {
    final container = ProviderContainer(
      overrides: [
        updateCheckerProvider
            .overrideWithValue(_FakeChecker(_release('v0.9.0'))),
      ],
    );
    addTearDown(container.dispose);
    await container.read(updateStatusProvider.notifier).check(force: true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: UpdateBanner())),
      ),
    );

    expect(find.text('Update available'), findsOneWidget);
    expect(find.textContaining('v0.9.0'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsNothing);
    expect(find.textContaining('v0.9.0'), findsNothing);
  });
}
