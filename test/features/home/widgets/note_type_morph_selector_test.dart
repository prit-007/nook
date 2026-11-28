import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/animated_squircle.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/widgets/note_type_morph_selector.dart';

void main() {
  group('NoteTypeMorphSelector', () {
    testWidgets('renders creative morphing squircle cards per NoteType',
        (tester) async {
      NoteType selected = NoteType.text;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return NoteTypeMorphSelector(
                  selected: selected,
                  onSelected: (t) => setState(() => selected = t),
                );
              },
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedSquircle), findsNWidgets(3));
      expect(find.text('Story'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Sketch'), findsOneWidget);

      await tester.tap(find.text('Sketch'));
      await tester.pumpAndSettle();
      expect(selected, NoteType.doodle);
    });
  });
}
