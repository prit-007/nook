import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/theme/design_tokens.dart';
import 'package:nook/features/editor/widgets/color_picker_sheet.dart';

void main() {
  testWidgets('renders title and description', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ColorPickerSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Note Color'), findsOneWidget);
    expect(find.text('Choose a seed color for this note'), findsOneWidget);
  });

  testWidgets('displays all color swatches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ColorPickerSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // 12 color swatches + 1 "none" circle = 13 GestureDetector circles
    final circles = find.byType(AnimatedContainer);
    expect(circles, findsAtLeastNWidgets(12));
  });

  testWidgets('returns selected color hex on tap', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ColorPickerSheet.show(
                  context,
                  currentSeed: null,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap the first color swatch (violet)
    final swatches = find.byType(AnimatedContainer);
    await tester.tap(swatches.at(1));
    await tester.pumpAndSettle();

    // Tap Done to confirm
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result, isNotEmpty);
    // Should be a hex string (6 chars)
    expect(result!.length, equals(6));
  });

  testWidgets('returns empty string when tapping none option', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await ColorPickerSheet.show(
                  context,
                  currentSeed: 'FF6750A4',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // First circle is the "none" option
    final swatches = find.byType(AnimatedContainer);
    await tester.tap(swatches.first);
    await tester.pumpAndSettle();

    // Tap Done to confirm
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, equals(''));
  });

  testWidgets('shows check on current seed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ColorPickerSheet.show(
                context,
                currentSeed: NookColors.seeds[0]
                    .toARGB32()
                    .toRadixString(16)
                    .substring(2),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Should show a check icon on the selected color
    expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon &&
            w.icon == HugeIcons.strokeRoundedCheckmarkCircle01),
        findsAtLeastNWidgets(1));
  });

  testWidgets('closes on drag down', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ColorPickerSheet.show(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Sheet should be visible
    expect(find.text('Note Color'), findsOneWidget);

    // Drag the sheet handle down to dismiss
    await tester.drag(
      find.byType(ColorPickerSheet),
      const Offset(0, 300),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Note Color'), findsNothing);
  });
}
