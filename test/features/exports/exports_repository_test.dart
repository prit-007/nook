import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/exports/exports_directory.dart';
import 'package:nook/features/exports/exports_repository.dart';

void main() {
  late Directory tempDir;
  late ExportsDirectory exportsDir;
  late ExportsRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nook-exports-test');
    exportsDir = ExportsDirectory(tempDir);
    repo = ExportsRepository(exportsDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('formatForFileName', () {
    test('detects zip/html/png/vault formats', () {
      expect(
        formatForFileName('nook-export-markdown-20261004.zip'),
        ExportFormat.markdownZip,
      );
      expect(
        formatForFileName('nook-export-html-20261004.zip'),
        ExportFormat.htmlZip,
      );
      expect(
        formatForFileName('nook-export-20261004.nook'),
        ExportFormat.vaultZip,
      );
      expect(formatForFileName('My Note.html'), ExportFormat.html);
      expect(formatForFileName('note-20261004.png'), ExportFormat.png);
    });
  });

  group('ExportsRepository', () {
    test('lists files newest first with format and sizes', () async {
      final older = exportsDir.file('older.html');
      await older.writeAsString('<html></html>');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final newer = exportsDir.file('nook-export-markdown-x.zip');
      await newer.writeAsBytes(List<int>.filled(2048, 1));

      final entries = await repo.list();
      expect(entries, hasLength(2));
      expect(entries.first.name, contains('markdown'));
      expect(entries.first.format, ExportFormat.markdownZip);
      expect(entries.first.sizeBytes, 2048);
      expect(entries.first.modifiedAt.isAfter(entries.last.modifiedAt), isTrue);
    });

    test('delete removes a file', () async {
      final file = exportsDir.file('temp.html');
      await file.writeAsString('x');
      await repo.delete(file.path);
      expect(file.existsSync(), isFalse);
      expect(await repo.list(), isEmpty);
    });

    test('deleteAll empties the folder', () async {
      await exportsDir.writeText('a.html', 'a');
      await exportsDir.writeBytes('b.png', [1, 2, 3]);
      await repo.deleteAll();
      expect(await repo.list(), isEmpty);
    });

    test('formatSize humanizes bytes', () {
      expect(ExportsRepository.formatSize(500), '500 B');
      expect(ExportsRepository.formatSize(2048), '2.0 KB');
      expect(ExportsRepository.formatSize(3 * 1024 * 1024), '3.0 MB');
    });

    test('formatDate is zero-padded', () {
      final dt = DateTime(2026, 1, 2, 3, 4);
      expect(ExportsRepository.formatDate(dt), '2026-01-02 03:04');
    });
  });
}
