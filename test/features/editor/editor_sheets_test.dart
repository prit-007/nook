import 'dart:typed_data';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_sheets.dart';

void main() {
  final now = DateTime(2026, 11, 23, 14, 30);
  final testNote = Note(
    id: 'sheet-note-1',
    title: 'Export Sample',
    type: NoteType.text,
    pinned: false,
    locked: false,
    deleted: false,
    syncVersion: 1,
    deviceOriginId: 'local',
    createdAt: now,
    updatedAt: now,
  );

  group('ExportPreviewSheet', () {
    testWidgets(
        'renders Export Preview title, Share button, and Save to Gallery button',
        (tester) async {
      final dummyBytes = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0A,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExportPreviewSheet(
              bytes: dummyBytes,
              noteTitle: 'Export Sample',
            ),
          ),
        ),
      );

      expect(find.text('Export Preview'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Save to Gallery'), findsOneWidget);
    });
  });

  group('showPaperStyleSheet', () {
    testWidgets('displays Blank, Ruled, Grid, Dotted paper options',
        (tester) async {
      NotePaperStyle? selectedStyle;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedStyle = await showPaperStyleSheet(
                    context,
                    currentStyle: NotePaperStyle.blank,
                  );
                },
                child: const Text('Open Paper Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Paper Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Paper Style'), findsOneWidget);
      expect(find.text('Blank (Clean)'), findsOneWidget);
      expect(find.text('Ruled (Lined)'), findsOneWidget);
      expect(find.text('Grid (Graph)'), findsOneWidget);
      expect(find.text('Dotted (Bullet)'), findsOneWidget);

      await tester.tap(find.text('Grid (Graph)'));
      await tester.pumpAndSettle();

      expect(selectedStyle, equals(NotePaperStyle.grid));
    });
  });

  group('NoteExportCapture', () {
    testWidgets('renders note title, date, and nook branding', (tester) async {
      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: 'Capturable paragraph content'),
          ],
        ),
      );
      final editorState = EditorState(document: document);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteExportCapture(
              note: testNote,
              editorState: editorState,
            ),
          ),
        ),
      );

      expect(find.text('Export Sample'), findsOneWidget);
      expect(find.text('Capturable paragraph content'), findsOneWidget);
      expect(find.text('nook.'), findsOneWidget);
    });
  });
}
