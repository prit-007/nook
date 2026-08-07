import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/widgets/filter_pill_bar.dart';

void main() {
  Widget buildBar({
    NoteType? selectedType,
    ValueChanged<NoteType?>? onTypeSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FilterPillBar(
          selectedType: selectedType,
          onTypeSelected: onTypeSelected ?? (_) {},
        ),
      ),
    );
  }

  group('FilterPillBar', () {
    testWidgets('renders all filter pills', (tester) async {
      await tester.pumpWidget(buildBar());
      await tester.pumpAndSettle();

      expect(find.text('All notes'), findsOneWidget);
      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('Checklists'), findsOneWidget);
      expect(find.text('Doodles'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
    });

    testWidgets('calls onTypeSelected when pill is tapped', (tester) async {
      NoteType? selected;
      await tester.pumpWidget(
        buildBar(onTypeSelected: (type) => selected = type),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Text'));
      await tester.pumpAndSettle();

      expect(selected, NoteType.text);
    });

    testWidgets('calls onTypeSelected with null for All notes', (tester) async {
      NoteType? selected = NoteType.text;
      await tester.pumpWidget(
        buildBar(
          selectedType: NoteType.text,
          onTypeSelected: (type) => selected = type,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All notes'));
      await tester.pumpAndSettle();

      expect(selected, isNull);
    });

    testWidgets('shows pin icon for Pinned pill', (tester) async {
      await tester.pumpWidget(buildBar());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });

    testWidgets('shows lock icon for Locked pill', (tester) async {
      await tester.pumpWidget(buildBar());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });
  });
}
