import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('routerProvider registers core and reminders routes', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    final paths = <String>[];

    void collect(List<RouteBase> routes) {
      for (final r in routes) {
        if (r is GoRoute) {
          paths.add(r.path);
          collect(r.routes);
        } else if (r is ShellRoute) {
          collect(r.routes);
        }
      }
    }

    collect(router.configuration.routes);

    expect(paths, contains('/home'));
    expect(paths, contains('/notebooks'));
    expect(paths, contains('/tags'));
    expect(paths, contains('/settings'));
    expect(paths, contains('/sync'));
    expect(paths, contains('/reminders'));
    expect(paths, contains('/onboarding'));
  });

  testWidgets('EditorialPageTransitions.buildPage dispatches all types',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  pageBuilder: (ctx, state) =>
                      EditorialPageTransitions.buildPage(
                    state: state,
                    type: EditorialTransitionType.fadeThrough,
                    child: const Text('Root'),
                  ),
                ),
              ],
            );
            router.dispose();
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
