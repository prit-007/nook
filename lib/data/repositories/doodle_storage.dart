import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/providers/talker_provider.dart';
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
  ///
  /// The sidecar file is written first and only then is the attachment row
  /// created/updated, so a failed write never leaves an orphaned row pointing
  /// at an empty path.
  Future<String> saveDoodle({
    required String noteId,
    required List<Stroke> strokes,
    DoodleBackground background = DoodleBackground.dotted,
    String? attachmentId,
  }) async {
    final id = attachmentId ?? const Uuid().v4();
    final file = _fileFor(id);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      DoodleStrokesCodec.encode(strokes, background: background),
    );

    final existing =
        attachmentId == null ? null : await attachments.getById(attachmentId);
    if (existing == null) {
      // Insert the row. This also covers inline editor doodles that were
      // created with only a document node (no row yet) — without it they would
      // never be packed into a sync bundle and the strokes would be lost.
      await attachments.addDoodle(
        noteId: noteId,
        filePath: file.path,
        id: id,
      );
    } else {
      await attachments.updateFilePath(id, file.path);
    }
    nookLog(NookLogKey.database, 'Doodle saved: $id', LogLevel.debug);
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
