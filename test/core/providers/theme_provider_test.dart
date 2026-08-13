import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults reduceMotion to false', () {
    final preference = ThemePreference();
    expect(preference.reduceMotion, isFalse);
  });

  test('setReduceMotion notifies and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final preference = await ThemePreference.load();
    var notified = false;
    preference.addListener(() => notified = true);

    preference.setReduceMotion(true);

    expect(preference.reduceMotion, isTrue);
    expect(notified, isTrue);

    // _save() is fire-and-forget; poll briefly for the mock write to land.
    var reloaded = await ThemePreference.load();
    for (var i = 0; !reloaded.reduceMotion && i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      reloaded = await ThemePreference.load();
    }
    expect(reloaded.reduceMotion, isTrue);
  });

  test('defaults amoledDark to false', () {
    final preference = ThemePreference();
    expect(preference.amoledDark, isFalse);
  });

  test('setAmoledDark notifies and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final preference = await ThemePreference.load();
    var notified = false;
    preference.addListener(() => notified = true);

    preference.setAmoledDark(true);

    expect(preference.amoledDark, isTrue);
    expect(notified, isTrue);

    // _save() is fire-and-forget; poll briefly for the mock write to land.
    var reloaded = await ThemePreference.load();
    for (var i = 0; !reloaded.amoledDark && i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      reloaded = await ThemePreference.load();
    }
    expect(reloaded.amoledDark, isTrue);
  });
}
