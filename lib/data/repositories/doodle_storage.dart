import 'dart:io';

import '../../features/doodle/doodle_controller.dart';
import '../../features/doodle/doodle_strokes_codec.dart';
import 'attachment_repository.dart';

/// Persists doodle strokes as JSON sidecar files referenced by the
/// Attachments table (type `doodleLayer`). The doodle node in the editor only
/// holds the attachment id.
class DoodleStorage {
  DoodleStorage({required this.attachments, required this.baseDir});

  final AttachmentRepository attachments;
  final Directory baseDir;

  File _fileFor(String attachmentId) =>
      File('${baseDir.path}/$attachmentId.doodle.json');

  /// Saves [strokes] for [noteId]. If [attachmentId] is provided the existing
  /// attachment is updated, otherwise a new one is created. Returns the
  /// attachment id.
  Future<String> saveDoodle({
    required String noteId,
    required List<Stroke> strokes,
    DoodleBackground background = DoodleBackground.dotted,
    String? attachmentId,
  }) async {
    final id = attachmentId ??
        await attachments.addDoodle(noteId: noteId, filePath: '');
    final file = _fileFor(id);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      DoodleStrokesCodec.encode(strokes, background: background),
    );
    await attachments.updateFilePath(id, file.path);
    return id;
  }

  /// Loads the strokes and background for [attachmentId].
  Future<DoodleData> loadDoodle(String attachmentId) async {
    final file = _fileFor(attachmentId);
    if (!await file.exists()) return const DoodleData();
    final source = await file.readAsString();
    return DoodleStrokesCodec.decode(source);
  }

  /// Deletes the sidecar file and attachment row for [attachmentId].
  Future<void> deleteDoodle(String attachmentId) async {
    final file = _fileFor(attachmentId);
    if (await file.exists()) {
      await file.delete();
    }
    await attachments.deleteImage(attachmentId);
  }
}
