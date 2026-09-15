import 'dart:io';

import '../data/database.dart';
import '../data/repositories/attachment_repository.dart';
import '../data/repositories/note_repository.dart';

/// Pre-transfer size estimate shown to the user before confirming a send.
class TransferEstimate {
  const TransferEstimate({
    required this.totalBytes,
    required this.noteCount,
    required this.hasLargeAttachments,
  });

  /// Total estimated bytes (notes + attachments + protocol overhead).
  final int totalBytes;

  /// Number of notes included in the estimate.
  final int noteCount;

  /// Whether any single attachment exceeds 1 MB.
  final bool hasLargeAttachments;
}

/// Estimates the total transfer size for [noteIds] by summing note content
/// lengths and attachment file sizes on disk. Missing files are skipped.
Future<TransferEstimate> estimateTransferSize(
  AppDatabase db,
  List<String> noteIds,
) async {
  if (noteIds.isEmpty) {
    return const TransferEstimate(
      totalBytes: 0,
      noteCount: 0,
      hasLargeAttachments: false,
    );
  }

  final noteRepo = NoteRepository(db);
  final attachmentRepo = AttachmentRepository(db);
  var totalBytes = 0;
  var hasLarge = false;
  var foundCount = 0;

  for (final noteId in noteIds) {
    final note = await noteRepo.getNoteById(noteId);
    if (note == null) continue;
    foundCount++;

    // Estimate note metadata + content overhead.
    totalBytes += (note.deltaContent?.length ?? 0);
    totalBytes += (note.plainText?.length ?? 0);
    totalBytes += (note.title.length);
    // CBOR/protocol overhead per note (~200 bytes for fields + framing).
    totalBytes += 200;

    final attachments = await attachmentRepo.getAllForNote(noteId);
    for (final att in attachments) {
      final file = File(att.filePath);
      if (await file.exists()) {
        final size = await file.length();
        totalBytes += size;
        if (size > 1024 * 1024) hasLarge = true;
      }
      final thumbPath = att.thumbnailPath;
      if (thumbPath != null && thumbPath.isNotEmpty) {
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          totalBytes += await thumbFile.length();
        }
      }
    }
  }

  // Protocol framing overhead: ~50 bytes per bundle envelope.
  totalBytes += 50;

  return TransferEstimate(
    totalBytes: totalBytes,
    noteCount: foundCount,
    hasLargeAttachments: hasLarge,
  );
}

/// Formats [bytes] into a human-readable string (e.g. `1.5 MB`).
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

/// Rough ETA assuming ~5 MB/s Wi-Fi throughput. Returns at least 1 second.
Duration estimateDuration(int bytes) {
  const bytesPerSecond = 5 * 1024 * 1024; // ~5 MB/s
  final seconds = (bytes / bytesPerSecond).ceil().clamp(1, 600);
  return Duration(seconds: seconds);
}

/// Thresholds that trigger the confirmation dialog.
const int confirmNoteThreshold = 50;
const int confirmSizeThreshold = 10 * 1024 * 1024; // 10 MB
