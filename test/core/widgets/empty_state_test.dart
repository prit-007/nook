import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/theme/nook_tokens.dart';
import 'package:nook/core/widgets/empty_state.dart';

void main() {
  group('EmptyState (Task 7.2 - Entrance Animation & No Repeating Bob)', () {
    testWidgets(
        'completes entrance animation and settles without infinite loop',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: HugeIcons.strokeRoundedNotebook01,
              title: 'Quiet Notebook',
              subtitle: 'No pages have been written yet.',
              animate: true,
            ),
          ),
        ),
      );

      // Verify that pumpAndSettle does not time out (which happens if repeat() is active)
      await tester.pumpAndSettle();

      // No scheduled frames remain after settling
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('Quiet Notebook'), findsOneWidget);
      expect(find.text('No pages have been written yet.'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedNotebook01),
        findsOneWidget,
      );
    });

    testWidgets('respects MediaQuery.disableAnimationsOf and skips animation',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: EmptyState(
                icon: HugeIcons.strokeRoundedBook01,
                title: 'No Animations Allowed',
                subtitle: 'Direct render to final state.',
                animate: true,
              ),
            ),
          ),
        ),
      );

      // When animations are disabled, no Animate widget is attached to the tree
      expect(find.byType(Animate), findsNothing);
      expect(find.text('No Animations Allowed'), findsOneWidget);
      expect(find.text('Direct render to final state.'), findsOneWidget);
    });

    testWidgets('respects animate: false flag and skips animation',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: HugeIcons.strokeRoundedTags,
              title: 'Manual Animation Disable',
              subtitle: 'Direct render without animation.',
              animate: false,
            ),
          ),
        ),
      );

      expect(find.byType(Animate), findsNothing);
      expect(find.text('Manual Animation Disable'), findsOneWidget);
    });

    testWidgets('runs entrance animation when animations are enabled',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: MaterialApp(
            home: Scaffold(
              body: EmptyState(
                icon: HugeIcons.strokeRoundedMagicWand01,
                title: 'Magic Entrance',
                subtitle: 'Graceful single fade and scale entrance.',
                animate: true,
              ),
            ),
          ),
        ),
      );

      // Animate widget is present while active
      expect(find.byType(Animate), findsOneWidget);

      // Successfully runs to completion without looping
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('EmptyState (Task 7.3 - Editorial Voice & Action Button)', () {
    testWidgets('renders editorial copy with appropriate styling',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: HugeIcons.strokeRoundedBookOpen01,
              title: 'The Unwritten Volume',
              subtitle: 'Ideas begin in quiet spaces. Draft your thoughts.',
              animate: false,
            ),
          ),
        ),
      );

      final titleWidget =
          tester.widget<Text>(find.text('The Unwritten Volume'));
      expect(titleWidget.style?.fontFamily, 'Playfair Display');
      expect(titleWidget.style?.fontSize, 20);
      expect(titleWidget.style?.fontWeight, FontWeight.w700);

      final subtitleWidget = tester.widget<Text>(
        find.text('Ideas begin in quiet spaces. Draft your thoughts.'),
      );
      expect(subtitleWidget.style?.fontFamily, 'Inter');
      expect(subtitleWidget.style?.fontSize, 14);
    });

    testWidgets(
        'renders actionable primary button via actionLabel and onActionPressed',
        (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: HugeIcons.strokeRoundedNote01,
              title: 'No Notes Found',
              subtitle: 'Start writing your first entry.',
              actionLabel: 'Create Note',
              onActionPressed: () => pressed = true,
              animate: false,
            ),
          ),
        ),
      );

      expect(find.text('Create Note'), findsOneWidget);
      final buttonFinder = find.byType(FilledButton);
      expect(buttonFinder, findsOneWidget);

      // Verify touch target is >= 48x48dp
      final buttonSize = tester.getSize(buttonFinder);
      expect(buttonSize.width, greaterThanOrEqualTo(NookTokens.kMinTapTarget));
      expect(buttonSize.height, greaterThanOrEqualTo(NookTokens.kMinTapTarget));
      expect(buttonSize.width, greaterThanOrEqualTo(48.0));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      // Verify text size is >= 12sp
      final textWidget = tester.widget<Text>(find.text('Create Note'));
      expect(textWidget.style?.fontSize,
          greaterThanOrEqualTo(NookTokens.kFontFloor));
      expect(textWidget.style?.fontSize, greaterThanOrEqualTo(12.0));

      // Tap triggers onActionPressed
      await tester.tap(buttonFinder);
      expect(pressed, isTrue);
    });

    testWidgets('supports EmptyState.action named constructor with actionIcon',
        (tester) async {
      var actionFired = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.action(
              icon: HugeIcons.strokeRoundedSearch01,
              title: 'No Discoveries',
              subtitle: 'Try searching with different terms.',
              actionLabel: 'Reset Search',
              actionIcon: HugeIcons.strokeRoundedRefresh01,
              onActionPressed: () => actionFired = true,
              animate: false,
            ),
          ),
        ),
      );

      expect(find.text('Reset Search'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedRefresh01),
        findsOneWidget,
      );

      final buttonFinder = find.byType(FilledButton);
      expect(buttonFinder, findsOneWidget);

      final buttonSize = tester.getSize(buttonFinder);
      expect(buttonSize.width, greaterThanOrEqualTo(48.0));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));

      await tester.tap(buttonFinder);
      expect(actionFired, isTrue);
    });

    testWidgets('supports custom action widget parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: HugeIcons.strokeRoundedFolder01,
              title: 'Custom Action Section',
              subtitle: 'Custom buttons or widgets can still be injected.',
              action: OutlinedButton(
                onPressed: () {},
                child: const Text('Custom Secondary Action'),
              ),
              animate: false,
            ),
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('Custom Secondary Action'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('renders nothing in action area when no action is provided',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              icon: HugeIcons.strokeRoundedFile01,
              title: 'Pure Information',
              subtitle: 'No action needed here.',
              animate: false,
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text('Pure Information'), findsOneWidget);
    });
  });
}
