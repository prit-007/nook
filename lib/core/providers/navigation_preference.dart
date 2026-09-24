import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'talker_provider.dart';

/// Persists the user's last navigated route across cold starts.
///
/// Stores only the shell's root destinations (`/home`, `/notebooks`,
/// `/tags`, `/trash`, `/settings`) — never leaf sub-routes. Sub-routes like
/// `/home/search`, `/notebooks/:id`, and `/settings/security` have no parent
/// page beneath them when restored as a sole go_router page, which would
/// leave the app stranded with a dead back button and (for `/home/search`,
/// which lives outside the shell) no way to navigate anywhere. Restoring a
/// section root keeps the shell and its dock/rail fully usable.
class NavigationPreference extends StateNotifier<String> {
  NavigationPreference([super.initial = '/home']);

  static const _key = 'last_route';
  static const _legacyKey = 'last_top_level_page';
  static const onboardingCompletedKey = 'onboarding_completed';

  /// Known top-level tab keys for backward compat with old stored values.
  static const _legacyRoutes = <String, String>{
    'home': '/home',
    'notebooks': '/notebooks',
    'tags': '/tags',
    'trash': '/trash',
    'settings': '/settings',
  };

  /// The only routes safe to restore on cold start — the shell's root
  /// destinations. Leaf sub-routes are deliberately excluded so a restored
  /// page never renders without its parent (see the class docs).
  static const _validRoutes = <String>[
    '/home',
    '/notebooks',
    '/tags',
    '/trash',
    '/settings',
  ];

  /// The full path to restore on next cold start.
  String get route => state;

  /// Overrides the current route without persisting (used at startup to
  /// force onboarding when onboarding hasn't been completed).
  void overrideRoute(String path) {
    state = path;
  }

  /// Persist [path] and update in-memory state.
  Future<void> remember(String path) async {
    if (!_isValid(path)) return;
    state = path;
    talker.debug('Last route set to $path');
    await _persist(path);
  }

  /// Persist [path] without updating in-memory state (fire-and-forget from
  /// the router redirect).
  static Future<void> rememberPath(String path) async {
    if (!_isValid(path)) return;
    await _persist(path);
  }

  /// Load the persisted route, migrating from the legacy key if needed.
  static Future<NavigationPreference> load() async {
    final prefs = await SharedPreferences.getInstance();

    // Try the new key first.
    var stored = prefs.getString(_key);

    // Migrate from old key if new key is missing.
    if (stored == null) {
      final legacy = prefs.getString(_legacyKey);
      if (legacy != null && _legacyRoutes.containsKey(legacy)) {
        stored = _legacyRoutes[legacy];
        await prefs.setString(_key, stored!);
        await prefs.remove(_legacyKey);
      }
    }

    if (stored != null && _isValid(stored)) {
      return NavigationPreference(stored);
    }
    return NavigationPreference('/home');
  }

  // -- internals -------------------------------------------------------------

  static Future<void> _persist(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, path);
  }

  static bool _isValid(String path) => _validRoutes.contains(path);

  /// Whether the user has completed the onboarding flow.
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(onboardingCompletedKey) ?? false;
  }

  /// Marks onboarding as completed.
  static Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingCompletedKey, true);
  }
}

final navigationPreferenceProvider =
    StateNotifierProvider<NavigationPreference, String>((ref) {
  return NavigationPreference();
});
