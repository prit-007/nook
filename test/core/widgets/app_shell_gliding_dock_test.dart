import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/widgets/app_shell.dart';

void main() {
  group('AppShell gliding dock indicator', () {
    testWidgets('animates gliding indicator alignment when tab changes',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const Center(child: Text('HomeBody')),
              ),
              GoRoute(
                path: '/notebooks',
                builder: (_, __) => const Center(child: Text('NotebooksBody')),
              ),
              GoRoute(
                path: '/tags',
                builder: (_, __) => const Center(child: Text('TagsBody')),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, __) => const Center(child: Text('SettingsBody')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final indicatorFinder = find.byKey(const ValueKey('gliding-dock-pill'));
      expect(indicatorFinder, findsOneWidget);
      final initialAlign = tester.widget<AnimatedAlign>(indicatorFinder);
      expect(initialAlign.alignment, const Alignment(-1.0, 0.0));

      await tester.tap(find.text('Notebooks'));
      await tester.pumpAndSettle();

      final movedAlign = tester.widget<AnimatedAlign>(indicatorFinder);
      expect(movedAlign.alignment, isNot(const Alignment(-1.0, 0.0)));
    });
  });
}
