import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/tables/notes.dart';

/// Imports Joplin `.jex` (tar archive of Markdown + metadata footer) exports.
class JoplinImporter {
  JoplinImporter(this._db);

  final AppDatabase _db;

  Future<int> importJexFile(File jexFile) async {
    if (!await jexFile.exists()) return 0;
    final bytes = await jexFile.readAsBytes();
    final archive = TarDecoder().decodeBytes(bytes);
    final noteRepo = NoteRepository(_db);

    var count = 0;
    for (final file in archive.files) {
      if (!file.isFile || !file.name.endsWith('.md')) continue;
      final raw = utf8.decode(file.content as List<int>, allowMalformed: true);
      final parsed = _parseJoplinRaw(raw);
      if (parsed == null) continue;

      await noteRepo.createNote(
        title: parsed.$1,
        type: NoteType.text,
        deviceOriginId: 'joplin-import',
        plainText: parsed.$2,
      );
      count++;
    }
    return count;
  }

  (String, String)? _parseJoplinRaw(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    if (lines.isEmpty) return null;

    // Joplin metadata footer starts where `id: ...` / `type_: ...` appears.
    var metaStart = lines.length;
    String? typeValue;
    for (var i = lines.length - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (RegExp(r'^[a-zA-Z0-9_]+:\s*.*$').hasMatch(line)) {
        metaStart = i;
        if (line.startsWith('type_:')) {
          typeValue = line.substring(6).trim();
        }
      } else {
        break;
      }
    }

    // In Joplin JEX, type_: 1 = note, type_: 2 = folder, type_: 5 = tag.
    if (typeValue != null && typeValue != '1') return null;

    final contentLines = lines.sublist(0, metaStart);
    while (contentLines.isNotEmpty && contentLines.last.trim().isEmpty) {
      contentLines.removeLast();
    }
    if (contentLines.isEmpty) return null;

    final title = contentLines.first.trim();
    final body = contentLines.length > 1
        ? contentLines.sublist(1).join('\n').trim()
        : '';
    return (title.isEmpty ? 'Imported Joplin Note' : title, body);
  }
}
