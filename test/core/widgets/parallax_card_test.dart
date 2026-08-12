import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/parallax_card.dart';

void main() {
  const cardHeight = 120.0;
  const viewportHeight = 800.0;

  Widget buildCard({required int index, required Widget child}) {
    return SizedBox(
      height: cardHeight,
      child: ParallaxCard(
        key: ValueKey('card-$index'),
        child: child,
      ),
    );
  }

  Future<ScrollController> pumpGrid(
    WidgetTester tester, {
    double intensity = 0.08,
    double initialOffset = 260,
  }) async {
    tester.view.physicalSize = const Size(400, viewportHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = ScrollController(initialScrollOffset: initialOffset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: List.generate(
              10,
              (i) => buildCard(
                index: i,
                child: Container(
                  color: Colors.indigo,
                  child: Center(child: Text('Card $i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return controller;
  }

  double parallaxDy(WidgetTester tester, int index) {
    final transforms = tester.widgetList<Transform>(
      find.descendant(
        of: find.byKey(ValueKey('card-$index')),
        matching: find.byType(Transform),
      ),
    );
    return transforms.first.transform.getTranslation().y;
  }

  /// All [Transform]s inside [of]; the ParallaxCard is the only widget in its
  /// subtree that produces one.
  Iterable<Transform> transformsIn(WidgetTester tester, Finder of) {
    return tester.widgetList<Transform>(
      find.descendant(of: of, matching: find.byType(Transform)),
    );
  }

  /// Expected vertical drift for a card whose top sits at [top] when the
  /// scroll offset is [pixels], mirroring the widget's model.
  double expectedDy(double top, double pixels, double intensity) {
    final cardMid = top + cardHeight / 2 - pixels;
    final factor = ((cardMid - viewportHeight / 2) / viewportHeight).clamp(
      -0.5,
      0.5,
    );
    return -factor * 2 * (intensity * cardHeight);
  }

  group('ParallaxCard', () {
    testWidgets('renders its child', (tester) async {
      await pumpGrid(tester);

      expect(find.text('Card 5'), findsOneWidget);
    });

    testWidgets('is static without a scrollable ancestor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ParallaxCard(child: Text('lonely')),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('lonely'), findsOneWidget);
      final transforms =
          transformsIn(tester, find.byType(ParallaxCard)).toList();
      // Without a scrollable the card renders statically (zero drift).
      expect(transforms, hasLength(1));
      expect(transforms.first.transform.getTranslation().y, 0);
    });

    testWidgets('stays centered when the card is at viewport center',
        (tester) async {
      await pumpGrid(tester, initialOffset: 260);

      // Card 5 (top 600, center 660) is centered at scroll offset 260.
      expect(parallaxDy(tester, 5), closeTo(0, 0.01));
    });

    testWidgets('drifts off-center as the user scrolls', (tester) async {
      final controller = await pumpGrid(tester, initialOffset: 260);

      expect(parallaxDy(tester, 5), closeTo(0, 0.01));

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      final pixels = controller.position.pixels;
      // Scrolling up moves the card above viewport center; content lags downward.
      expect(parallaxDy(tester, 5), greaterThan(0));
      expect(
        parallaxDy(tester, 5),
        closeTo(expectedDy(600, pixels, 0.08), 0.01),
      );
    });

    testWidgets('bounds the drift to intensity * height', (tester) async {
      await pumpGrid(tester, intensity: 0.2, initialOffset: 0);

      // Card 0 near the top of the viewport is at a maximal offset.
      expect(
        parallaxDy(tester, 0).abs(),
        lessThanOrEqualTo(0.2 * cardHeight),
      );
    });

    testWidgets('respects the enabled flag', (tester) async {
      tester.view.physicalSize = const Size(400, viewportHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: List.generate(
                10,
                (i) => SizedBox(
                  height: cardHeight,
                  child: ParallaxCard(
                    enabled: false,
                    child: Container(
                      color: Colors.indigo,
                      child: Center(child: Text('Card $i')),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(
        transformsIn(tester, find.byType(ParallaxCard)),
        isEmpty,
      );
    });
  });
}
