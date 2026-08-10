import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/doodle_storage.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/doodle/doodle_canvas.dart';
import 'package:nook/features/doodle/doodle_canvas_screen.dart';
import 'package:nook/features/doodle/doodle_controller.dart';
import 'package:nook/features/doodle/doodle_toolbar.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: DoodleCanvasScreen(noteId: 'note-1'),
      ),
    );
  }

  testWidgets('renders close button', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('renders undo button', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.byIcon(Icons.undo_rounded), findsWidgets);
  });

  testWidgets('renders redo button', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.byIcon(Icons.redo_rounded), findsWidgets);
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
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('renders background selector button', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
  });

  testWidgets('background button opens a sheet with all four templates',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Blank'), findsOneWidget);
    expect(find.text('Dotted'), findsOneWidget);
    expect(find.text('Ruled'), findsOneWidget);
    expect(find.text('Graph'), findsOneWidget);
  });

  testWidgets('selecting a template switches the canvas background',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(find.byKey(const ValueKey('doodle-bg-dotted')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ruled'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('doodle-bg-ruled')), findsOneWidget);
    expect(find.byKey(const ValueKey('doodle-bg-dotted')), findsNothing);
  });

  group('persistence', () {
    late AppDatabase db;
    late Directory tempDir;
    late DoodleStorage storage;
    String? pushedResult;

    setUp(() async {
      db = createTestDb();
      tempDir = await Directory.systemTemp.createTemp('doodle_screen_');
      storage = DoodleStorage(
        attachments: AttachmentRepository(db),
        baseDir: tempDir,
      );
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-1'),
              type: NoteType.text,
              title: const Value('Test'),
              deviceOriginId: 'device-1',
            ),
          );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Widget host({String? attachmentId}) {
      return ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    pushedResult = await Navigator.of(context).push<String>(
                      MaterialPageRoute<String>(
                        builder: (_) => DoodleCanvasScreen(
                          noteId: 'note-1',
                          attachmentId: attachmentId,
                          storage: storage,
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> openCanvas(WidgetTester tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    void drawStroke(WidgetTester tester) {
      const pointer = 5;
      tester.binding.handlePointerEvent(
        const PointerDownEvent(pointer: pointer, position: Offset(100, 100)),
      );
      tester.binding.handlePointerEvent(
        const PointerMoveEvent(
          pointer: pointer,
          position: Offset(140, 140),
          pressure: 0.5,
        ),
      );
      tester.binding.handlePointerEvent(
        const PointerUpEvent(pointer: pointer, position: Offset(140, 140)),
      );
    }

    testWidgets('creates an attachment row and pops with its id',
        (tester) async {
      pushedResult = null;
      await openCanvas(tester);

      drawStroke(tester);
      await tester.pump();

      await tester.tap(find.text('Done'));
      // Pump to let drift addDoodle complete and pop fire.
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(pushedResult, isNotNull);
      expect(pushedResult, isNotEmpty);
      expect(find.text('open'), findsOneWidget);

      // Verify the attachment row was created in the database.
      final attachments = await db.select(db.attachments).get();
      expect(attachments.length, equals(1));
      expect(attachments.first.noteId, equals('note-1'));
      expect(attachments.first.type, equals(AttachmentType.doodleLayer));
      expect(attachments.first.id, equals(pushedResult));
    });

    testWidgets('loads an existing doodle for editing', (tester) async {
      // saveDoodle does dart:io; must use runAsync.
      final existingId = (await tester.runAsync(() => storage.saveDoodle(
            noteId: 'note-1',
            strokes: [
              Stroke(
                points: [const StrokePoint(Offset(200, 200), pressure: 0.8)],
                width: 7,
              ),
            ],
            background: DoodleBackground.ruled,
          )))!;

      pushedResult = null;
      await tester.pumpWidget(host(attachmentId: existingId));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump();

      expect(pushedResult, equals(existingId));

      // The file was already saved above; verify it round-trips.
      await tester.runAsync(() async {
        final saved = await storage.loadDoodle(existingId);
        expect(saved.strokes.length, equals(1));
        expect(saved.strokes.first.points.single.pressure, equals(0.8));
        expect(saved.background, equals(DoodleBackground.ruled));
      });
    });
  });
}
