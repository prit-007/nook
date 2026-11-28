import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/repositories/note_link_repository.dart';
import 'package:nook/features/editor/widgets/backlinks_panel.dart';

void main() {
  group('Interactive BacklinkGraphView', () {
    testWidgets('renders InteractiveViewer, edge canvas, and selectable nodes',
        (tester) async {
      String? selectedId;
      const graph = BacklinkGraphData(
        centerTitle: 'Core Architecture',
        incoming: [
          NoteLinkHit(
            noteId: 'n-in-1',
            title: 'Meeting Notes',
            linkedNoteId: 'center',
            linkedTitle: 'Core Architecture',
          ),
        ],
        relatedTitles: ['Sync Spec'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BacklinkGraphView(
                graph: graph,
                onSelectNote: (id) => selectedId = id,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Core Architecture'), findsOneWidget);
      expect(find.text('Meeting Notes'), findsOneWidget);

      await tester.tap(find.text('Meeting Notes'));
      expect(selectedId, 'n-in-1');
    });
  });
}
