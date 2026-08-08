import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/editor/note_exporter.dart';

void main() {
  group('NoteExporter.captureToPng', () {
    test('returns Uint8List of PNG bytes', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);

      final bytes = await NoteExporter.imageToPng(image);
      image.dispose();
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
    });

    test('PNG bytes start with PNG signature', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);

      final bytes = await NoteExporter.imageToPng(image);
      image.dispose();
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });

    test('larger images produce larger output', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      final picture = recorder.endRecording();

      final small = await picture.toImage(50, 50);
      final bytes1x = await NoteExporter.imageToPng(small);
      small.dispose();

      final large = await picture.toImage(200, 200);
      final bytes2x = await NoteExporter.imageToPng(large);
      large.dispose();

      expect(bytes2x.lengthInBytes, greaterThan(bytes1x.lengthInBytes));
    });
  });

  group('NoteExporter.saveToFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('note_export_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saves PNG file to disk', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);

      final filePath = '${tempDir.path}/test_note.png';
      final savedPath =
          await NoteExporter.saveImageToFile(image, filePath: filePath);
      image.dispose();

      expect(savedPath, filePath);
      expect(await File(savedPath).exists(), isTrue);
    });

    test('saved file contains valid PNG header', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);

      final filePath = '${tempDir.path}/test_note.png';
      await NoteExporter.saveImageToFile(image, filePath: filePath);
      image.dispose();

      final bytes = await File(filePath).readAsBytes();
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
    });
  });

  group('NoteExporter.generateFileName', () {
    test('generates name with note title', () {
      final name = NoteExporter.generateFileName('My Great Note');
      expect(name, startsWith('my-great-note'));
      expect(name, endsWith('.png'));
    });

    test('sanitizes special characters', () {
      final name = NoteExporter.generateFileName('Note: "Hello" & World!');
      expect(name, isNot(contains(':')));
      expect(name, isNot(contains('"')));
      expect(name, isNot(contains('&')));
      expect(name, isNot(contains('!')));
    });

    test('truncates long titles', () {
      final longTitle = 'A' * 200;
      final name = NoteExporter.generateFileName(longTitle);
      expect(name.length, lessThanOrEqualTo(110));
    });

    test('handles empty title', () {
      final name = NoteExporter.generateFileName('');
      expect(name, startsWith('note-'));
      expect(name, endsWith('.png'));
    });
  });
}
