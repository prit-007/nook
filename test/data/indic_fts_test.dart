import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/search_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  group('Indic matra & Unicode FTS5 search', () {
    test('indexes and matches Devanagari & Gujarati text with matras',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final noteRepo = NoteRepository(db);
      final searchRepo = SearchRepository(db);

      await noteRepo.createNote(
        id: 'indic-hi-1',
        title: 'हिंदी नोट्स',
        plainText: 'पुस्तक और कविता संग्रह',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );
      await noteRepo.createNote(
        id: 'indic-gu-1',
        title: 'ગુજરાતી નોંધ',
        plainText: 'વાર્તા અને કવિતા',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );

      final hiResults = await searchRepo.searchNotes('पुस्तक');
      expect(hiResults.map((n) => n.id), contains('indic-hi-1'));

      final guResults = await searchRepo.searchNotes('કવિતા');
      expect(guResults.map((n) => n.id), contains('indic-gu-1'));
    });
  });
}
