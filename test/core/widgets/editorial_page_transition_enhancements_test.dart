import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/editorial_page_transition.dart';

void main() {
  group('EditorialPageTransitions enhancements', () {
    testWidgets('sharedAxis adds outgoing parallax SlideTransition',
        (tester) async {
      final anim = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      )..value = 0.5;
      final secondary = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      )..value = 0.5;
      addTearDown(() {
        anim.dispose();
        secondary.dispose();
      });

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Builder(
              builder: (context) => EditorialPageTransitions.buildSharedAxis(
                context,
                anim,
                secondary,
                const Text('Page'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SlideTransition), findsOneWidget);
      expect(find.byType(FractionalTranslation), findsNWidgets(2));
    });

    testWidgets('containerTransform applies ClipRRect corner morph mid-flight',
        (tester) async {
      final anim = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 400),
      )..value = 0.5;
      final secondary = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 400),
      )..value = 0.0;
      addTearDown(() {
        anim.dispose();
        secondary.dispose();
      });

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Builder(
              builder: (context) =>
                  EditorialPageTransitions.buildContainerTransform(
                context,
                anim,
                secondary,
                const Text('Editor'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ClipRRect), findsOneWidget);
    });

    testWidgets('all builders respect disableAnimations accessibility setting',
        (tester) async {
      final anim = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      )..value = 0.5;
      final secondary = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 300),
      )..value = 0.0;
      addTearDown(() {
        anim.dispose();
        secondary.dispose();
      });

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) => EditorialPageTransitions.buildSharedAxis(
                context,
                anim,
                secondary,
                const Text('Reduced'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SlideTransition), findsNothing);
      expect(find.byType(ScaleTransition), findsNothing);
      expect(find.byType(FadeTransition), findsOneWidget);
    });
  });
}
