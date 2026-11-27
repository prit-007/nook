import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/database.dart';
import '../../data/repositories/checklist_item_repository.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/tables/notes.dart';

/// Imports Markdown files from an Obsidian vault directory into Nook.
///
/// Parses optional YAML frontmatter (`tags: [...]`), `# Heading` titles, and
/// Markdown task lists (`- [ ]` / `- [x]`).
class ObsidianImporter {
  ObsidianImporter(this._db);

  final AppDatabase _db;

  Future<int> importDirectory(Directory vaultDir) async {
    if (!await vaultDir.exists()) return 0;

    final noteRepo = NoteRepository(_db);
    final checklistRepo = ChecklistItemRepository(_db);
    final tagRepo = TagRepository(_db);

    var count = 0;
    await for (final entity in vaultDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.md')) continue;
      final raw = await entity.readAsString();
      final parsed = _parseMarkdown(
        raw,
        fallbackTitle: p.basenameWithoutExtension(entity.path),
      );

      final isChecklist = parsed.checklistItems.isNotEmpty;
      final note = await noteRepo.createNote(
        title: parsed.title,
        type: isChecklist ? NoteType.checklist : NoteType.text,
        deviceOriginId: 'obsidian-import',
        plainText: parsed.body,
      );

      for (final item in parsed.checklistItems) {
        await checklistRepo.addItem(
          noteId: note.id,
          text: item.$1,
          checked: item.$2,
        );
      }

      for (final tag in parsed.tags) {
        await tagRepo.assignTagByName(note.id, tag);
      }

      count++;
    }
    return count;
  }

  ({
    String title,
    String body,
    List<String> tags,
    List<(String, bool)> checklistItems,
  }) _parseMarkdown(String raw, {required String fallbackTitle}) {
    var content = raw.replaceAll('\r\n', '\n');
    final tags = <String>[];

    if (content.startsWith('---\n')) {
      final endIdx = content.indexOf('\n---\n', 4);
      if (endIdx != -1) {
        final fm = content.substring(4, endIdx);
        content = content.substring(endIdx + 5);
        for (final line in fm.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('tags:')) {
            final val = trimmed.substring(5).trim();
            if (val.startsWith('[') && val.endsWith(']')) {
              final inner = val.substring(1, val.length - 1);
              tags.addAll(
                inner
                    .split(',')
                    .map((s) => s.trim().replaceAll('#', ''))
                    .where((s) => s.isNotEmpty),
              );
            }
          }
        }
      }
    }

    var title = fallbackTitle;
    final bodyLines = <String>[];
    final checklistItems = <(String, bool)>[];
    var titleExtracted = false;

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (!titleExtracted && trimmed.startsWith('# ')) {
        title = trimmed.substring(2).trim();
        titleExtracted = true;
        continue;
      }
      if (trimmed.startsWith('- [x] ') || trimmed.startsWith('- [X] ')) {
        checklistItems.add((trimmed.substring(6).trim(), true));
      } else if (trimmed.startsWith('- [ ] ')) {
        checklistItems.add((trimmed.substring(6).trim(), false));
      } else {
        bodyLines.add(line);
      }
    }

    return (
      title: title,
      body: bodyLines.join('\n').trim(),
      tags: tags,
      checklistItems: checklistItems,
    );
  }
}
