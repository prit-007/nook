import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/navigation_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<NavigationPreference> loadReloaded() async {
    var reloaded = await NavigationPreference.load();
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      reloaded = await NavigationPreference.load();
    }
    return reloaded;
  }

  group('rememberPath', () {
    test('persists all shell root destinations', () async {
      SharedPreferences.setMockInitialValues({});
      for (final root in [
        '/home',
        '/notebooks',
        '/tags',
        '/trash',
        '/settings'
      ]) {
        await NavigationPreference.rememberPath(root);
        final reloaded = await NavigationPreference.load();
        expect(reloaded.route, root, reason: 'expected $root to persist');
      }
    });

    test('rejects leaf sub-routes so they never become the restore target',
        () async {
      SharedPreferences.setMockInitialValues({'last_route': '/home'});
      const leaves = [
        '/home/search',
        '/notebooks/abc-123',
        '/tags/xyz',
        '/settings/security',
        '/settings/logs',
        '/note/new',
        '/note/abc-123',
        '/sync',
      ];
      for (final leaf in leaves) {
        await NavigationPreference.rememberPath(leaf);
        final reloaded = await loadReloaded();
        expect(reloaded.route, '/home',
            reason: '$leaf must not be persisted/restored');
      }
    });
  });

  group('load', () {
    test('restores a previously persisted root route', () async {
      SharedPreferences.setMockInitialValues({'last_route': '/notebooks'});
      final navigation = await NavigationPreference.load();
      expect(navigation.route, '/notebooks');
    });

    test('falls back to /home when a leaf sub-route was stored (bug scenario)',
        () async {
      // A previous app version persisted the /home/search leaf; on cold start
      // that page had no parent and the back button was dead. It must now
      // resolve to /home instead of stranding the user on search.
      SharedPreferences.setMockInitialValues({'last_route': '/home/search'});
      final navigation = await NavigationPreference.load();
      expect(navigation.route, '/home');
    });

    test('falls back to /home for any non-shell sub-route', () async {
      SharedPreferences.setMockInitialValues(
          {'last_route': '/settings/security'});
      final navigation = await NavigationPreference.load();
      expect(navigation.route, '/home');
    });

    test('migrates legacy top-level keys', () async {
      SharedPreferences.setMockInitialValues(
          {'last_top_level_page': 'settings'});
      final navigation = await NavigationPreference.load();
      expect(navigation.route, '/settings');
    });
  });
}
