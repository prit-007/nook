import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/theme/app_motion.dart';
import 'package:nook/core/widgets/editorial_page_transition.dart';

void main() {
  Widget buildTestHarness({
    required Widget child,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: child,
          ),
        ),
      ),
    );
  }

  Finder inTransition(Finder matching) {
    return find.descendant(
      of: find.byType(EditorialPageTransition),
      matching: matching,
    );
  }

  group('EditorialPageTransitions constants & tokens', () {
    test('uses AppMotion tokens for durations', () {
      expect(EditorialPageTransitions.sharedAxisDuration, AppMotion.page);
      expect(
        EditorialPageTransitions.sharedAxisReverseDuration,
        AppMotion.medium2,
      );

      expect(EditorialPageTransitions.slideUpDuration, AppMotion.modal);
      expect(
        EditorialPageTransitions.slideUpReverseDuration,
        AppMotion.medium2,
      );

      expect(EditorialPageTransitions.fadeThroughDuration, AppMotion.standard);
      expect(
        EditorialPageTransitions.fadeThroughReverseDuration,
        AppMotion.short4,
      );

      expect(
        EditorialPageTransitions.containerTransformDuration,
        AppMotion.page,
      );
      expect(
        EditorialPageTransitions.containerTransformReverseDuration,
        AppMotion.medium2,
      );
    });

    test('resolves correct durations for transition types', () {
      expect(
        EditorialPageTransitions.durationFor(
          EditorialTransitionType.sharedAxis,
        ),
        AppMotion.page,
      );
      expect(
        EditorialPageTransitions.reverseDurationFor(
          EditorialTransitionType.sharedAxis,
        ),
        AppMotion.medium2,
      );

      expect(
        EditorialPageTransitions.durationFor(EditorialTransitionType.slideUp),
        AppMotion.modal,
      );
      expect(
        EditorialPageTransitions.reverseDurationFor(
          EditorialTransitionType.slideUp,
        ),
        AppMotion.medium2,
      );

      expect(
        EditorialPageTransitions.durationFor(
          EditorialTransitionType.fadeThrough,
        ),
        AppMotion.standard,
      );
      expect(
        EditorialPageTransitions.reverseDurationFor(
          EditorialTransitionType.fadeThrough,
        ),
        AppMotion.short4,
      );

      expect(
        EditorialPageTransitions.durationFor(
          EditorialTransitionType.containerTransform,
        ),
        AppMotion.page,
      );
      expect(
        EditorialPageTransitions.reverseDurationFor(
          EditorialTransitionType.containerTransform,
        ),
        AppMotion.medium2,
      );
    });
  });

  group('EditorialPageTransitions CustomTransitionPage helpers', () {
    test('sharedAxis helper creates CustomTransitionPage with correct settings',
        () {
      const pageKey = ValueKey('shared-axis-key');
      const child = Text('Shared Axis Content', style: TextStyle(fontSize: 14));

      final page = EditorialPageTransitions.sharedAxis<void>(
        key: pageKey,
        axis: Axis.horizontal,
        child: child,
      );

      expect(page, isA<CustomTransitionPage<void>>());
      expect(page.key, pageKey);
      expect(page.transitionDuration, AppMotion.page);
      expect(page.reverseTransitionDuration, AppMotion.medium2);
    });

    test('sharedAxis helper works with vertical axis', () {
      const pageKey = ValueKey('shared-axis-v-key');
      const child = Text('Vertical Content', style: TextStyle(fontSize: 14));

      final page = EditorialPageTransitions.sharedAxis<void>(
        key: pageKey,
        axis: Axis.vertical,
        child: child,
      );

      expect(page, isA<CustomTransitionPage<void>>());
      expect(page.key, pageKey);
    });

    test('slideUp helper creates CustomTransitionPage with correct settings',
        () {
      const pageKey = ValueKey('slide-up-key');
      const child = Text('Slide Up Content', style: TextStyle(fontSize: 14));

      final page = EditorialPageTransitions.slideUp<void>(
        key: pageKey,
        child: child,
      );

      expect(page, isA<CustomTransitionPage<void>>());
      expect(page.key, pageKey);
      expect(page.transitionDuration, AppMotion.modal);
      expect(page.reverseTransitionDuration, AppMotion.medium2);
    });

    test(
        'fadeThrough helper creates CustomTransitionPage with correct settings',
        () {
      const pageKey = ValueKey('fade-through-key');
      const child =
          Text('Fade Through Content', style: TextStyle(fontSize: 14));

      final page = EditorialPageTransitions.fadeThrough<void>(
        key: pageKey,
        child: child,
      );

      expect(page, isA<CustomTransitionPage<void>>());
      expect(page.key, pageKey);
      expect(page.transitionDuration, AppMotion.standard);
      expect(page.reverseTransitionDuration, AppMotion.short4);
    });

    test(
        'containerTransform helper creates CustomTransitionPage with correct settings',
        () {
      const pageKey = ValueKey('container-key');
      const child = Text('Container Content', style: TextStyle(fontSize: 14));

      final page = EditorialPageTransitions.containerTransform<void>(
        key: pageKey,
        child: child,
      );

      expect(page, isA<CustomTransitionPage<void>>());
      expect(page.key, pageKey);
      expect(page.transitionDuration, AppMotion.page);
      expect(page.reverseTransitionDuration, AppMotion.medium2);
    });
  });

  group('EditorialPageTransition widget', () {
    testWidgets(
        'sharedAxis (horizontal) animates opacity, scale, and horizontal slide',
        (
      tester,
    ) async {
      late AnimationController anim;
      late AnimationController secAnim;

      await tester.pumpWidget(
        buildTestHarness(
          child: _AnimationTestHost(
            onInit: (vsync) {
              anim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 400),
              );
              secAnim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 300),
              );
            },
            builder: (context) {
              return EditorialPageTransition.sharedAxis(
                animation: anim,
                secondaryAnimation: secAnim,
                axis: Axis.horizontal,
                child: const Text('Shared Axis Child',
                    style: TextStyle(fontSize: 14)),
              );
            },
          ),
        ),
      );

      expect(find.text('Shared Axis Child'), findsOneWidget);
      expect(inTransition(find.byType(FadeTransition)), findsWidgets);
      expect(inTransition(find.byType(SlideTransition)), findsOneWidget);
      expect(inTransition(find.byType(ScaleTransition)), findsWidgets);
      expect(inTransition(find.byType(RepaintBoundary)), findsWidgets);

      // Initial state: t = 0
      anim.value = 0.0;
      await tester.pump();

      final slide = tester.widget<SlideTransition>(
        inTransition(find.byType(SlideTransition)),
      );
      expect(slide.position.value.dx, closeTo(0.08, 0.01));
      expect(slide.position.value.dy, 0.0);

      // Intermediate state: t = 0.5
      anim.value = 0.5;
      await tester.pump();
      expect(slide.position.value.dx, lessThan(0.08));
      expect(slide.position.value.dx, greaterThan(0.0));

      // Final state: t = 1.0
      anim.value = 1.0;
      await tester.pump();
      expect(slide.position.value.dx, 0.0);
      expect(slide.position.value.dy, 0.0);
    });

    testWidgets('sharedAxis (vertical) animates vertical slide offset', (
      tester,
    ) async {
      late AnimationController anim;
      late AnimationController secAnim;

      await tester.pumpWidget(
        buildTestHarness(
          child: _AnimationTestHost(
            onInit: (vsync) {
              anim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 400),
              );
              secAnim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 300),
              );
            },
            builder: (context) {
              return EditorialPageTransition.sharedAxis(
                animation: anim,
                secondaryAnimation: secAnim,
                axis: Axis.vertical,
                child: const Text('Vertical Child',
                    style: TextStyle(fontSize: 14)),
              );
            },
          ),
        ),
      );

      anim.value = 0.0;
      await tester.pump();

      final slide = tester.widget<SlideTransition>(
        inTransition(find.byType(SlideTransition)),
      );
      expect(slide.position.value.dx, 0.0);
      expect(slide.position.value.dy, closeTo(0.08, 0.01));

      anim.value = 1.0;
      await tester.pump();
      expect(slide.position.value.dy, 0.0);
    });

    testWidgets('slideUp animates vertical slide and secondary scale', (
      tester,
    ) async {
      late AnimationController anim;
      late AnimationController secAnim;

      await tester.pumpWidget(
        buildTestHarness(
          child: _AnimationTestHost(
            onInit: (vsync) {
              anim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 400),
              );
              secAnim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 300),
              );
            },
            builder: (context) {
              return EditorialPageTransition.slideUp(
                animation: anim,
                secondaryAnimation: secAnim,
                child: const Text('Slide Up Child',
                    style: TextStyle(fontSize: 14)),
              );
            },
          ),
        ),
      );

      expect(find.text('Slide Up Child'), findsOneWidget);

      anim.value = 0.0;
      await tester.pump();

      final slide = tester.widget<SlideTransition>(
        inTransition(find.byType(SlideTransition)),
      );
      expect(slide.position.value.dx, 0.0);
      expect(slide.position.value.dy, closeTo(0.06, 0.01));

      anim.value = 1.0;
      await tester.pump();
      expect(slide.position.value.dy, 0.0);

      // Now test secondary animation (outgoing scale down)
      secAnim.value = 0.0;
      await tester.pump();
      final scale = tester.widget<ScaleTransition>(
        inTransition(find.byType(ScaleTransition)),
      );
      expect(scale.scale.value, 1.0);

      secAnim.value = 1.0;
      await tester.pump();
      expect(scale.scale.value, closeTo(0.96, 0.01));
    });

    testWidgets('fadeThrough animates interval fade and scale', (tester) async {
      late AnimationController anim;
      late AnimationController secAnim;

      await tester.pumpWidget(
        buildTestHarness(
          child: _AnimationTestHost(
            onInit: (vsync) {
              anim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 300),
              );
              secAnim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 200),
              );
            },
            builder: (context) {
              return EditorialPageTransition.fadeThrough(
                animation: anim,
                secondaryAnimation: secAnim,
                child: const Text('Fade Through Child',
                    style: TextStyle(fontSize: 14)),
              );
            },
          ),
        ),
      );

      expect(find.text('Fade Through Child'), findsOneWidget);

      // At t = 0.1, enter fade has not started (interval 0.2 to 1.0)
      anim.value = 0.1;
      await tester.pump();
      final enterFade = tester
          .widgetList<FadeTransition>(
            inTransition(find.byType(FadeTransition)),
          )
          .first;
      expect(enterFade.opacity.value, 0.0);

      // At t = 1.0, enter fade and scale are fully settled
      anim.value = 1.0;
      await tester.pump();
      expect(enterFade.opacity.value, 1.0);

      final scale = tester.widget<ScaleTransition>(
        inTransition(find.byType(ScaleTransition)),
      );
      expect(scale.scale.value, 1.0);
    });

    testWidgets('containerTransform expands with scale, subtle rise, and fade',
        (
      tester,
    ) async {
      late AnimationController anim;
      late AnimationController secAnim;

      await tester.pumpWidget(
        buildTestHarness(
          child: _AnimationTestHost(
            onInit: (vsync) {
              anim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 400),
              );
              secAnim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 300),
              );
            },
            builder: (context) {
              return EditorialPageTransition.containerTransform(
                animation: anim,
                secondaryAnimation: secAnim,
                child: const Text('Container Child',
                    style: TextStyle(fontSize: 14)),
              );
            },
          ),
        ),
      );

      expect(find.text('Container Child'), findsOneWidget);

      anim.value = 0.0;
      await tester.pump();

      final scaleWidgets = tester
          .widgetList<ScaleTransition>(
              inTransition(find.byType(ScaleTransition)))
          .toList();
      expect(scaleWidgets, isNotEmpty);
      expect(scaleWidgets.first.scale.value, closeTo(0.90, 0.02));

      final slide = tester.widget<SlideTransition>(
        inTransition(find.byType(SlideTransition)),
      );
      expect(slide.position.value.dy, closeTo(0.04, 0.01));

      anim.value = 1.0;
      await tester.pump();
      expect(scaleWidgets.first.scale.value, 1.0);
      expect(slide.position.value.dy, 0.0);

      // Test secondary animation (outgoing screen scales down slightly)
      secAnim.value = 1.0;
      await tester.pump();
      expect(scaleWidgets.last.scale.value, closeTo(0.95, 0.02));
    });

    testWidgets('respects disableAnimations for reduce motion', (tester) async {
      late AnimationController anim;
      late AnimationController secAnim;

      await tester.pumpWidget(
        buildTestHarness(
          disableAnimations: true,
          child: _AnimationTestHost(
            onInit: (vsync) {
              anim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 400),
              );
              secAnim = AnimationController(
                vsync: vsync,
                duration: const Duration(milliseconds: 300),
              );
            },
            builder: (context) {
              return EditorialPageTransition.sharedAxis(
                animation: anim,
                secondaryAnimation: secAnim,
                child: const Text('Reduced Motion Child',
                    style: TextStyle(fontSize: 14)),
              );
            },
          ),
        ),
      );

      expect(find.text('Reduced Motion Child'), findsOneWidget);
      // In reduced motion, slide and scale transitions inside EditorialPageTransition are bypassed
      expect(inTransition(find.byType(SlideTransition)), findsNothing);
      expect(inTransition(find.byType(ScaleTransition)), findsNothing);
    });
  });

  group('EditorialPageRoute', () {
    testWidgets('pushes page with EditorialPageRoute', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      EditorialPageRoute(
                        transitionType: EditorialTransitionType.slideUp,
                        builder: (_) => const Scaffold(
                          body: Text('Destination Screen',
                              style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    );
                  },
                  child:
                      const Text('Push Route', style: TextStyle(fontSize: 14)),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Push Route'), findsOneWidget);
      expect(find.text('Destination Screen'), findsNothing);

      await tester.tap(find.text('Push Route'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Destination Screen'), findsOneWidget);
      expect(find.byType(EditorialPageTransition), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Destination Screen'), findsOneWidget);
    });
  });
}

class _AnimationTestHost extends StatefulWidget {
  const _AnimationTestHost({
    required this.onInit,
    required this.builder,
  });

  final void Function(TickerProvider vsync) onInit;
  final WidgetBuilder builder;

  @override
  State<_AnimationTestHost> createState() => _AnimationTestHostState();
}

class _AnimationTestHostState extends State<_AnimationTestHost>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.onInit(this);
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}
