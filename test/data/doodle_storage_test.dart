import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/doodle_storage.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/doodle/doodle_controller.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late AttachmentRepository repo;
  late Directory tempDir;
  late DoodleStorage storage;

  setUp(() async {
    db = createTestDb();
    repo = AttachmentRepository(db);
    tempDir = await Directory.systemTemp.createTemp('doodle_storage_');
    storage = DoodleStorage(attachments: repo, baseDir: tempDir);

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

  Stroke sampleStroke() => Stroke(
        points: [const StrokePoint(Offset(1, 2), pressure: 0.5)],
        color: const Color(0xFF112233),
        width: 5,
        tool: DoodleTool.highlighter,
        opacity: 0.35,
      );

  group('saveDoodle', () {
    test('creates an attachment row and a sidecar file', () async {
      final id = await storage.saveDoodle(
        noteId: 'note-1',
        strokes: [sampleStroke()],
        background: DoodleBackground.ruled,
      );

      expect(id, isA<String>());
      expect(id, isNotEmpty);

      final row = await repo.getById(id);
      expect(row, isNotNull);
      expect(row!.type, equals(AttachmentType.doodleLayer));

      final file = File('${tempDir.path}/$id.doodle.json');
      expect(await file.exists(), isTrue);
    });

    test('returns an id whose file round-trips through loadDoodle', () async {
      final id = await storage.saveDoodle(
        noteId: 'note-1',
        strokes: [sampleStroke()],
        background: DoodleBackground.graph,
      );

      final data = await storage.loadDoodle(id);
      expect(data.background, equals(DoodleBackground.graph));
      expect(data.strokes.length, equals(1));
      final stroke = data.strokes.first;
      expect(stroke.color, equals(const Color(0xFF112233)));
      expect(stroke.width, equals(5.0));
      expect(stroke.tool, equals(DoodleTool.highlighter));
      expect(stroke.opacity, equals(0.35));
      expect(stroke.points.single.pressure, equals(0.5));
    });

    test('updates an existing attachment when attachmentId is given',
        () async {
      final id = await storage.saveDoodle(
        noteId: 'note-1',
        strokes: [sampleStroke()],
      );

      final updated = await storage.saveDoodle(
        noteId: 'note-1',
        strokes: [sampleStroke(), sampleStroke()],
        attachmentId: id,
      );

      expect(updated, equals(id));
      final rows = await (db.select(db.attachments)
            ..where((a) => a.noteId.equals('note-1')))
          .get();
      expect(rows, hasLength(1));
      expect((await storage.loadDoodle(id)).strokes.length, equals(2));
    });
  });

  group('loadDoodle', () {
    test('returns empty data for a missing id', () async {
      final data = await storage.loadDoodle('no-such-id');
      expect(data.strokes, isEmpty);
      expect(data.background, equals(DoodleBackground.dotted));
    });

    test('returns empty data when the sidecar file is missing', () async {
      final id = await repo.addDoodle(noteId: 'note-1', filePath: '/missing.doodle.json');
      final data = await storage.loadDoodle(id);
      expect(data.strokes, isEmpty);
    });
  });

  group('deleteDoodle', () {
    test('removes the attachment row and sidecar file', () async {
      final id = await storage.saveDoodle(
        noteId: 'note-1',
        strokes: [sampleStroke()],
      );

      await storage.deleteDoodle(id);

      expect(await repo.getById(id), isNull);
      expect(await File('${tempDir.path}/$id.doodle.json').exists(), isFalse);
    });
  });
}
