import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/platform/ocr_service.dart';
import 'package:nook/core/platform/voice_capture_service.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/search_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:path/path.dart' as p;

class _FakeOcrService implements OcrService {
  _FakeOcrService(this.output);
  final String output;

  @override
  Future<OcrResult> extractText(String imagePath) async {
    return OcrResult(text: output);
  }
}

void main() {
  group('Phase 5 — Offline capture & search', () {
    test('5.1 OfflineVoiceModelManager verifies SHA-256 on user-imported model',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('nook_stt_model_test');
      addTearDown(() => tempDir.delete(recursive: true));

      final modelBytes = List<int>.generate(128, (i) => i % 256);
      final expectedHash = sha256.convert(modelBytes).toString();
      final modelFile = File(p.join(tempDir.path, 'ggml-tiny.bin'))
        ..writeAsBytesSync(modelBytes);

      final manager = OfflineVoiceModelManager(storageDirectory: tempDir);
      final imported = await manager.importModel(
        sourceFile: modelFile,
        expectedSha256: expectedHash,
      );
      expect(imported.existsSync(), isTrue);

      await expectLater(
        () => manager.importModel(
          sourceFile: modelFile,
          expectedSha256: '0000badhash',
        ),
        throwsFormatException,
      );
    });

    test(
        '5.2 SemanticSearchIndex ranks unlocked notes and excludes locked notes',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);

      final n1 = await noteRepo.createNote(
        title: 'Encryption Architecture',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Argon2id key derivation and SQLCipher storage',
      );
      final n2 = await noteRepo.createNote(
        title: 'Grocery List',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Bananas, coffee beans, oat milk',
      );
      final locked = await noteRepo.createNote(
        title: 'Secret Encryption Keys',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Private Argon2id passphrase',
      );
      await noteRepo.updateNote(locked.id, locked: true);

      final semantic = SemanticSearchIndex(db, enabled: true);
      await semantic.rebuildIndex();

      final hits = await semantic.search('Argon2id cipher');
      expect(hits.map((h) => h.note.id), contains(n1.id));
      expect(hits.map((h) => h.note.id), isNot(contains(locked.id)));
      expect(hits.first.note.id, isNot(n2.id));

      // Disabled semantic search returns empty cleanly.
      final disabled = SemanticSearchIndex(db, enabled: false);
      expect(await disabled.search('Argon2id'), isEmpty);
    });

    test(
        '5.3 HandwritingSearchIndexer indexes unlocked doodle OCR into FTS and skips locked',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);
      final searchRepo = SearchRepository(db);

      final doodle = await noteRepo.createNote(
        title: 'Whiteboard Sketch',
        type: NoteType.doodle,
        deviceOriginId: 'dev-1',
      );
      final lockedDoodle = await noteRepo.createNote(
        title: 'Locked Sketch',
        type: NoteType.doodle,
        deviceOriginId: 'dev-1',
      );
      await noteRepo.updateNote(lockedDoodle.id, locked: true);

      final indexer = HandwritingSearchIndexer(
        db: db,
        ocrService: _FakeOcrService('Quarterly Roadmap Milestone'),
      );

      final indexed1 = await indexer.indexDoodleThumbnail(
        noteId: doodle.id,
        thumbnailPath: '/tmp/fake.png',
      );
      expect(indexed1, isTrue);

      final indexed2 = await indexer.indexDoodleThumbnail(
        noteId: lockedDoodle.id,
        thumbnailPath: '/tmp/fake.png',
      );
      expect(indexed2, isFalse);

      final ftsHits = await searchRepo.searchNotes('Roadmap');
      expect(ftsHits.map((n) => n.id), [doodle.id]);
    });
  });
}
