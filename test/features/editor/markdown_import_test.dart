import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/markdown_import.dart';
import 'package:drift/native.dart';

void main() {
  group('looksLikeMarkdown', () {
    test('detects headings, lists, bold, fences, quotes', () {
      expect(looksLikeMarkdown('# Title'), isTrue);
      expect(looksLikeMarkdown('- item'), isTrue);
      expect(looksLikeMarkdown('1. item'), isTrue);
      expect(looksLikeMarkdown('```dart\ncode\n```'), isTrue);
      expect(looksLikeMarkdown('**bold**'), isTrue);
      expect(looksLikeMarkdown('> quote'), isTrue);
    });

    test('plain prose is not markdown', () {
      expect(looksLikeMarkdown('just some notes'), isFalse);
      expect(looksLikeMarkdown(''), isFalse);
    });
  });

  group('markdownToAppFlowyJson', () {
    test('converts heading + paragraph + checklist', () {
      const md = '# Meeting\n\nDiscuss roadmap\n\n- [ ] buy milk\n- [x] done';
      final json = markdownToAppFlowyJson(md);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded.containsKey('document'), isTrue);
      final plain = extractPlainTextFromAppFlowyJson(json);
      expect(plain, contains('Meeting'));
      expect(plain, contains('Discuss roadmap'));
      expect(plain, contains('buy milk'));
    });

    test('extractPlainText returns empty for invalid json', () {
      expect(extractPlainTextFromAppFlowyJson(null), isEmpty);
      expect(extractPlainTextFromAppFlowyJson('nope'), isEmpty);
    });
  });

  group('importMarkdownAsNote', () {
    late AppDatabase db;
    late NoteRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = NoteRepository(db);
    });

    tearDown(() async => db.close());

    test('creates note from markdown with derived title', () async {
      final note = await importMarkdownAsNote(
        repo,
        '# Passport\n\nBook appointment',
      );
      expect(note.title, 'Passport');
      expect(note.plainText, contains('Book appointment'));
      expect(note.deltaContent, isNotNull);
      expect(note.type, NoteType.text);
    });

    test('detects checklist type from markdown tasks', () async {
      final note = await importMarkdownAsNote(
        repo,
        '# Errands\n\n- [ ] buy milk',
      );
      expect(note.type, NoteType.checklist);
    });

    test('respects titleOverride (file basename)', () async {
      final note = await importMarkdownAsNote(
        repo,
        '# Other\n\nbody',
        titleOverride: 'notes-from-keep',
      );
      expect(note.title, 'notes-from-keep');
    });

    test('falls back to Untitled for empty markdown', () async {
      final note = await importMarkdownAsNote(repo, '');
      expect(note.title, 'Untitled');
    });
  });

  group('MarkdownImporter.importFiles', () {
    late AppDatabase db;
    late NoteRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = NoteRepository(db);
    });

    tearDown(() async => db.close());

    test('imports multiple .md files using basename titles', () async {
      final dir = await Directory.systemTemp.createTemp('nook-md');
      addTearDown(() => dir.delete(recursive: true));
      final f1 = File('${dir.path}/keep-note.md');
      await f1.writeAsString('# From Keep\n\nhello');
      final f2 = File('${dir.path}/obsidian-note.md');
      await f2.writeAsString('# From Obsidian\n\nworld');

      final result = await MarkdownImporter(repo).importFiles([f1, f2]);
      expect(result.isSuccessful, isTrue);
      expect(result.notesImported, 2);

      final notes = await repo.getAllNotes();
      expect(notes.map((n) => n.title),
          containsAll({'keep-note', 'obsidian-note'}));
    });

    test('returns error result on failure', () async {
      final missing = File('/tmp/does-not-exist-nook-md.md');
      final result = await MarkdownImporter(repo).importFiles([missing]);
      expect(result.isSuccessful, isFalse);
      expect(result.error, isNotNull);
    });
  });
}
