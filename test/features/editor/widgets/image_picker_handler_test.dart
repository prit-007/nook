import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/features/editor/widgets/image_picker_handler.dart';
import 'package:nook/data/tables/notes.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

/// A fake [XFile] that provides deterministic bytes.
class FakeXFile extends XFile {
  FakeXFile(this._bytes, {String name = 'photo.jpg'})
      : super('fake://$name', name: name);

  final Uint8List _bytes;

  @override
  Future<Uint8List> readAsBytes() async => _bytes;
}

/// A fake [ImagePicker] that returns a pre-configured [XFile].
class FakeImagePicker extends ImagePicker {
  FakeImagePicker({this.xFile});

  final XFile? xFile;

  @override
  Future<XFile?> pickImage({
    ImageSource? source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice? preferredCameraDevice,
    bool? requestFullMetadata,
  }) async {
    return xFile;
  }
}

/// Creates a minimal valid JPEG (smallest valid JPEG file header).
Uint8List get _testJpegBytes => Uint8List.fromList([
      0xFF,
      0xD8,
      0xFF,
      0xE0,
      0x00,
      0x10,
      0x4A,
      0x46,
      0x49,
      0x46,
      0x00,
      0x01,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x01,
      0x00,
      0x00,
      0xFF,
      0xD9,
    ]);

/// Creates a minimal valid PNG (1x1 transparent pixel).
Uint8List get _testPngBytes => Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x62,
      0x00,
      0x00,
      0x00,
      0x02,
      0x00,
      0x01,
      0xE5,
      0x27,
      0xDE,
      0xFC,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);

void main() {
  late AppDatabase db;
  late AttachmentRepository repo;
  late Directory tempDir;

  setUp(() async {
    db = createTestDb();
    repo = AttachmentRepository(db);
    tempDir = await Directory.systemTemp.createTemp('image_handler_');

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

  group('pickAndStore', () {
    test('creates file and attachment row from a picked image', () async {
      final fakePicker = FakeImagePicker(
        xFile: FakeXFile(_testPngBytes, name: 'test_image.png'),
      );
      final handler = ImagePickerHandler(
        attachments: repo,
        baseDir: tempDir,
        picker: fakePicker,
      );

      final result = await handler.pickAndStore(noteId: 'note-1');

      expect(result, isNotNull);
      expect(result!.attachmentId, isNotEmpty);

      final row = await repo.getById(result.attachmentId);
      expect(row, isNotNull);
      expect(row!.filePath, endsWith('.png'));
      expect(await File(row.filePath).exists(), isTrue);
    });

    test('generates a thumbnail file', () async {
      final fakePicker = FakeImagePicker(
        xFile: FakeXFile(_testPngBytes, name: 'thumb_test.png'),
      );
      final handler = ImagePickerHandler(
        attachments: repo,
        baseDir: tempDir,
        picker: fakePicker,
      );

      final result = await handler.pickAndStore(noteId: 'note-1');

      expect(result, isNotNull);
      final row = await repo.getById(result!.attachmentId);
      expect(row!.thumbnailPath, isNotNull);
      expect(await File(row.thumbnailPath!).exists(), isTrue);
    });

    test('returns null when user cancels picker', () async {
      final fakePicker = FakeImagePicker(xFile: null);
      final handler = ImagePickerHandler(
        attachments: repo,
        baseDir: tempDir,
        picker: fakePicker,
      );

      final result = await handler.pickAndStore(noteId: 'note-1');
      expect(result, isNull);
    });

    test('updates an existing attachment when existingAttachmentId is provided',
        () async {
      // Create an existing image attachment.
      final existingId = await repo.addImage(
        noteId: 'note-1',
        filePath: '/old/path.jpg',
      );

      final fakePicker = FakeImagePicker(
        xFile: FakeXFile(_testJpegBytes, name: 'replacement.jpg'),
      );
      final handler = ImagePickerHandler(
        attachments: repo,
        baseDir: tempDir,
        picker: fakePicker,
      );

      final result = await handler.pickAndStore(
        noteId: 'note-1',
        existingAttachmentId: existingId,
      );

      expect(result, isNotNull);
      expect(result!.attachmentId, existingId);
      final row = await repo.getById(existingId);
      expect(row!.filePath, isNot(equals('/old/path.jpg')));
      expect(await File(row.filePath).exists(), isTrue);
    });

    test('creates attachments directory if it does not exist', () async {
      final fakePicker = FakeImagePicker(
        xFile: FakeXFile(_testPngBytes, name: 'new_dir.png'),
      );
      final handler = ImagePickerHandler(
        attachments: repo,
        baseDir: tempDir,
        picker: fakePicker,
      );

      expect(Directory('${tempDir.path}/attachments').existsSync(), isFalse);
      await handler.pickAndStore(noteId: 'note-1');
      expect(Directory('${tempDir.path}/attachments').existsSync(), isTrue);
    });
  });
}
