import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/attachment_repository.dart';

/// Result of picking and storing an image for a note.
class ImagePickResult {
  const ImagePickResult({
    required this.attachmentId,
    required this.filePath,
    required this.thumbnailPath,
  });

  final String attachmentId;
  final String filePath;
  final String thumbnailPath;
}

/// Handles picking an image from the device, persisting it to the
/// filesystem, generating a thumbnail, and registering it in the
/// Attachments table.
///
/// The [picker] argument is injectable so unit tests can provide a
/// deterministic fake without depending on a real platform channel.
class ImagePickerHandler {
  ImagePickerHandler({
    required this.attachments,
    required this.baseDir,
    this.picker,
    this.thumbnailWidth = 400,
  });

  final AttachmentRepository attachments;
  final Directory baseDir;
  final ImagePicker? picker;
  final int thumbnailWidth;

  /// Picks an image from the user's gallery and stores it.
  ///
  /// Returns an [ImagePickResult] on success, or `null` if the user cancels.
  Future<ImagePickResult?> pickAndStore({
    required String noteId,
    String? existingAttachmentId,
  }) async {
    final xFile = await (picker ?? ImagePicker()).pickImage(
      source: ImageSource.gallery,
    );
    if (xFile == null) return null;

    final sourceBytes = await xFile.readAsBytes();
    final ext = _extensionFromName(xFile.name);

    // Write the full-size image to the attachments directory.
    final attachmentsDir = Directory('${baseDir.path}/attachments');
    if (!attachmentsDir.existsSync()) {
      await attachmentsDir.create(recursive: true);
    }

    // Persist to the database first to get the canonical ID.
    String attachmentId;
    if (existingAttachmentId != null) {
      attachmentId = existingAttachmentId;
    } else {
      attachmentId = await attachments.addImage(
        noteId: noteId,
        filePath: '',
        thumbnailPath: '',
      );
    }

    final filePath = '${attachmentsDir.path}/$attachmentId.$ext';
    await File(filePath).writeAsBytes(sourceBytes);

    // Generate and write the thumbnail.
    final thumbBytes = _generateThumbnail(sourceBytes, xFile.name);
    final thumbPath = '${attachmentsDir.path}/${attachmentId}_thumb.$ext';
    await File(thumbPath).writeAsBytes(thumbBytes);

    // Update the DB row with the actual file paths.
    await attachments.updateFilePath(attachmentId, filePath);
    await attachments.updateThumbnail(attachmentId, thumbPath);

    return ImagePickResult(
      attachmentId: attachmentId,
      filePath: filePath,
      thumbnailPath: thumbPath,
    );
  }

  /// Generates a resized JPEG thumbnail from [sourceBytes].
  ///
  /// Returns raw PNG bytes suitable for writing to disk. If the source
  /// cannot be decoded the original bytes are returned unchanged.
  Uint8List _generateThumbnail(Uint8List sourceBytes, String fileName) {
    try {
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) return sourceBytes;
      final resized = img.copyResize(
        decoded,
        width: thumbnailWidth,
        maintainAspect: true,
      );
      return Uint8List.fromList(img.encodePng(resized));
    } catch (_) {
      return sourceBytes;
    }
  }

  String _extensionFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'jpg';
    return name.substring(dot + 1).toLowerCase();
  }
}
