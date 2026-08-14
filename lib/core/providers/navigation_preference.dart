import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'talker_provider.dart';

/// Persists the user's last navigated route across cold starts.
///
/// Stores the full path (e.g. `/notebooks/abc123`, `/settings/security`)
/// instead of just the top-level tab key, so deep-linked screens are
/// restored on relaunch.
class NavigationPreference extends StateNotifier<String> {
  NavigationPreference([super.initial = '/home']);

  static const _key = 'last_route';
  static const _legacyKey = 'last_top_level_page';

  /// Known top-level tab keys for backward compat with old stored values.
  static const _legacyRoutes = <String, String>{
    'home': '/home',
    'notebooks': '/notebooks',
    'tags': '/tags',
    'trash': '/trash',
    'settings': '/settings',
  };

  /// All paths the shell is allowed to restore.  Sub-routes like
  /// `/notebooks/:id` are accepted via prefix matching.
  static const _validPrefixes = <String>[
    '/home',
    '/notebooks',
    '/tags',
    '/trash',
    '/settings',
  ];

  /// The full path to restore on next cold start.
  String get route => state;

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

  static bool _isValid(String path) {
    return _validPrefixes.any((p) => path == p || path.startsWith('$p/'));
  }
}

final navigationPreferenceProvider =
    StateNotifierProvider<NavigationPreference, String>((ref) {
  return NavigationPreference();
});
