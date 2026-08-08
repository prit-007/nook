import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/doodle/doodle_canvas.dart';
import 'package:nook/features/doodle/doodle_canvas_screen.dart';
import 'package:nook/features/doodle/doodle_toolbar.dart';

void main() {
  Widget buildScreen() {
    return const MaterialApp(
      home: DoodleCanvasScreen(noteId: 'note-1'),
    );
  }

  testWidgets('renders close button', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('renders undo button', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.byIcon(Icons.undo), findsWidgets);
  });

  testWidgets('renders redo button', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.byIcon(Icons.redo), findsWidgets);
  });

  testWidgets('renders Done button', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('renders DoodleCanvas', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.byType(DoodleCanvas), findsOneWidget);
  });

  testWidgets('renders DoodleToolbar', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.byType(DoodleToolbar), findsOneWidget);
  });

  testWidgets('close button is tappable', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    // Just verify the button is there and can be tapped without error
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
