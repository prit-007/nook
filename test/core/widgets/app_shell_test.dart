import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/widgets/app_shell.dart';

void main() {
  Widget buildShell({
    String initialLocation = '/home',
    double screenWidth = 400,
    double screenHeight = 800,
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) =>
                  const Scaffold(body: Center(child: Text('Home Content'))),
            ),
            GoRoute(
              path: '/notebooks',
              builder: (_, __) => const Scaffold(
                  body: Center(child: Text('Notebooks Content'))),
            ),
            GoRoute(
              path: '/tags',
              builder: (_, __) =>
                  const Scaffold(body: Center(child: Text('Tags Content'))),
            ),
            GoRoute(
              path: '/trash',
              builder: (_, __) =>
                  const Scaffold(body: Center(child: Text('Trash Content'))),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, __) =>
                  const Scaffold(body: Center(child: Text('Settings Content'))),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: Size(screenWidth, screenHeight),
        ),
        child: child!,
      ),
    );
  }

  // ===========================================================================
  // Mobile layout (< 600px)
  // ===========================================================================
  group('Mobile layout', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();
      expect(find.text('Home Content'), findsOneWidget);
    });

    testWidgets('shows floating dock with 5 items', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Notebooks'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('dock has glassmorphism blur', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('dock has rounded pill shape', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ClipRRect &&
              widget.borderRadius is BorderRadius &&
              (widget.borderRadius as BorderRadius).topLeft.x == 36,
        ),
        findsOneWidget,
      );
    });

    testWidgets('highlights selected dock item', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      final homeText = tester.widget<Text>(find.text('Home'));
      final effectiveStyle =
          DefaultTextStyle.of(tester.element(find.text('Home'))).style;
      expect(
        (homeText.style?.fontWeight ??
                effectiveStyle.fontWeight ??
                FontWeight.normal)
            .value,
        greaterThanOrEqualTo(FontWeight.w600.value),
      );
    });

    testWidgets('navigates to notebooks on dock tap', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notebooks'));
      await tester.pumpAndSettle();

      expect(find.text('Notebooks Content'), findsOneWidget);
    });

    testWidgets('navigates to tags on dock tap', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();

      expect(find.text('Tags Content'), findsOneWidget);
    });

    testWidgets('navigates to trash on dock tap', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trash'));
      await tester.pumpAndSettle();

      expect(find.text('Trash Content'), findsOneWidget);
    });

    testWidgets('navigates to settings on dock tap', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Content'), findsOneWidget);
    });

    testWidgets('navigates back to home on dock tap', (tester) async {
      await tester.pumpWidget(buildShell(initialLocation: '/settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('Home Content'), findsOneWidget);
    });

    testWidgets('does not show NavigationRail', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  // ===========================================================================
  // Wide layout (>= 600px — tablet / desktop / web)
  // ===========================================================================
  group('Wide layout', () {
    testWidgets('shows NavigationRail instead of dock', (tester) async {
      await tester.pumpWidget(buildShell(screenWidth: 800));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(buildShell(screenWidth: 800));
      await tester.pumpAndSettle();

      expect(find.text('Home Content'), findsOneWidget);
    });

    testWidgets('shows all 5 rail destinations', (tester) async {
      await tester.pumpWidget(buildShell(screenWidth: 800));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Notebooks'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('navigates via rail tap', (tester) async {
      await tester.pumpWidget(buildShell(screenWidth: 800));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notebooks'));
      await tester.pumpAndSettle();

      expect(find.text('Notebooks Content'), findsOneWidget);
    });

    testWidgets('navigates to settings via rail', (tester) async {
      await tester.pumpWidget(buildShell(screenWidth: 800));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Settings Content'), findsOneWidget);
    });

    testWidgets('shows app icon in rail leading', (tester) async {
      await tester.pumpWidget(buildShell(screenWidth: 800));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    });
  });
}
