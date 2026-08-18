import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/doodle_storage.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/doodle/doodle_controller.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late Directory baseDir;
  late AttachmentRepository attachments;
  late DoodleStorage storage;

  setUp(() async {
    db = createTestDb();
    baseDir = await Directory.systemTemp.createTemp('nook-doodle-test');
    attachments = AttachmentRepository(db);
    storage = DoodleStorage(attachments: attachments, baseDir: baseDir);
  });

  tearDown(() async {
    await db.close();
    await baseDir.delete(recursive: true);
  });

  List<Stroke> makeStrokes() => [
        Stroke(
          points: const [
            StrokePoint(Offset(10, 10), pressure: 0.5),
            StrokePoint(Offset(50, 50), pressure: 0.8),
          ],
          color: const Color(0xFF000000),
          width: 3,
          opacity: 1,
        ),
      ];

  test('saveDoodle with a known attachmentId updates the existing row',
      () async {
    final note = await NoteRepository(db).createNote(
      title: 'Doodle note',
      type: NoteType.doodle,
      deviceOriginId: 'local',
    );
    final attachmentId = await attachments.addDoodle(
      noteId: note.id,
      filePath: '',
    );

    await storage.saveDoodle(
      noteId: note.id,
      strokes: makeStrokes(),
      attachmentId: attachmentId,
    );

    final row = await attachments.getById(attachmentId);
    expect(row, isNotNull);
    expect(row!.type, AttachmentType.doodleLayer);
    expect(row.filePath, '${baseDir.path}/$attachmentId.doodle.json');
  });

  test(
      'saveDoodle with an attachmentId that has NO row creates one '
      '(inline editor doodle bug)', () async {
    final note = await NoteRepository(db).createNote(
      title: 'Inline doodle',
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    // An inline editor doodle only carries a document node id — no row yet.
    const attachmentId = 'inline-doodle-1';

    final savedId = await storage.saveDoodle(
      noteId: note.id,
      strokes: makeStrokes(),
      attachmentId: attachmentId,
    );

    expect(savedId, attachmentId);
    final row = await attachments.getById(attachmentId);
    expect(row, isNotNull,
        reason: 'the row must exist so sendNotes packs the doodle');
    expect(row!.filePath, '${baseDir.path}/$attachmentId.doodle.json');

    // The strokes round-trip so nothing is lost.
    final loaded = await storage.loadDoodle(attachmentId);
    expect(loaded.strokes, hasLength(1));
    expect(loaded.strokes.first.points, hasLength(2));
  });
}
