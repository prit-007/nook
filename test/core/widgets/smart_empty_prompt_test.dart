import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/widgets/smart_empty_prompt.dart';

void main() {
  group('SmartEmptyPrompt', () {
    testWidgets('renders title, subtitle, and triggers starter actions',
        (tester) async {
      String? triggered;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SmartEmptyPrompt(
                icon: HugeIcons.strokeRoundedNote01,
                title: 'Start your vault',
                subtitle: 'Capture notes, checklists, or sketches offline.',
                actions: [
                  SmartStarterAction(
                    label: 'New Note',
                    icon: HugeIcons.strokeRoundedPencil,
                    onTap: () => triggered = 'note',
                  ),
                  SmartStarterAction(
                    label: 'Checklist',
                    icon: HugeIcons.strokeRoundedCheckList,
                    onTap: () => triggered = 'checklist',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start your vault'), findsOneWidget);
      expect(find.text('New Note'), findsOneWidget);
      expect(find.text('Checklist'), findsOneWidget);

      await tester.tap(find.text('Checklist'));
      expect(triggered, 'checklist');
    });
  });
}
