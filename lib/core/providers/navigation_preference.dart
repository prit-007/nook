import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NavigationPreference extends StateNotifier<String> {
  NavigationPreference([super.initial = 'home']);

  static const _key = 'last_top_level_page';
  static const routes = <String, String>{
    'home': '/home',
    'notebooks': '/notebooks',
    'tags': '/tags',
    'trash': '/trash',
    'settings': '/settings',
  };

  String get route => routes[state] ?? '/home';

  Future<void> remember(String path) async {
    final entry = routes.entries.where((entry) => entry.value == path);
    if (entry.isEmpty) return;
    state = entry.first.key;
    await rememberPath(path);
  }

  static Future<void> rememberPath(String path) async {
    final entry = routes.entries.where((entry) => entry.value == path);
    if (entry.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, entry.first.key);
  }

  static Future<NavigationPreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return NavigationPreference(routes.containsKey(value) ? value! : 'home');
  }
}

final navigationPreferenceProvider =
    StateNotifierProvider<NavigationPreference, String>((ref) {
  return NavigationPreference();
});
