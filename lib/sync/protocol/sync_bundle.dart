import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:crypto/crypto.dart';

/// A single note entry within a sync bundle.
class SyncNoteEntry {
  const SyncNoteEntry({
    required this.noteId,
    required this.syncVersion,
    required this.updatedAt,
    required this.deviceOriginId,
    required this.noteFields,
    this.checklistItems,
    this.attachmentBytes,
  });

  final String noteId;
  final int syncVersion;
  final DateTime updatedAt;
  final String deviceOriginId;
  final Map<String, dynamic> noteFields;
  final List<Map<String, dynamic>>? checklistItems;
  final Uint8List? attachmentBytes;

  Uint8List toCbor() {
    final map = CborMap.fromEntries([
      MapEntry(CborString('noteId'), CborString(noteId)),
      MapEntry(CborString('syncVersion'), CborSmallInt(syncVersion)),
      MapEntry(CborString('updatedAt'),
          CborSmallInt(updatedAt.millisecondsSinceEpoch)),
      MapEntry(CborString('deviceOriginId'), CborString(deviceOriginId)),
      MapEntry(CborString('noteFields'), CborValue(noteFields)),
      if (checklistItems != null)
        MapEntry(CborString('checklistItems'), CborValue(checklistItems)),
      MapEntry(CborString('hasAttachment'), CborBool(attachmentBytes != null)),
      if (attachmentBytes != null)
        MapEntry(CborString('attachmentBytes'), CborBytes(attachmentBytes!)),
    ]);
    return Uint8List.fromList(cborEncode(map));
  }

  factory SyncNoteEntry.fromCbor(Uint8List bytes) {
    final cborVal = cborDecode(bytes);
    final map = cborVal.toObject() as Map<dynamic, dynamic>;

    final rawChecklist = map['checklistItems'] as List<dynamic>?;
    final checklistItems = rawChecklist?.map((item) {
      final m = item as Map<dynamic, dynamic>;
      return m.map((k, v) => MapEntry(k.toString(), v));
    }).toList();

    Uint8List? attachment;
    if (map['hasAttachment'] == true && map['attachmentBytes'] != null) {
      final raw = map['attachmentBytes'];
      if (raw is Uint8List) {
        attachment = raw;
      } else {
        attachment = Uint8List.fromList(raw as List<int>);
      }
    }

    return SyncNoteEntry(
      noteId: map['noteId'] as String,
      syncVersion: map['syncVersion'] as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      deviceOriginId: map['deviceOriginId'] as String,
      noteFields: (map['noteFields'] as Map<dynamic, dynamic>)
          .map((k, v) => MapEntry(k.toString(), v)),
      checklistItems: checklistItems,
      attachmentBytes: attachment,
    );
  }
}

/// A bundle of notes to be sent over the sync transport.
class SyncBundle {
  const SyncBundle({
    required this.protocolVersion,
    required this.senderDeviceId,
    required this.senderDeviceName,
    required this.sentAt,
    required this.notes,
  });

  final String protocolVersion;
  final String senderDeviceId;
  final String senderDeviceName;
  final DateTime sentAt;
  final List<SyncNoteEntry> notes;

  Uint8List toCbor() {
    final map = CborMap.fromEntries([
      MapEntry(CborString('protocolVersion'), CborString(protocolVersion)),
      MapEntry(CborString('senderDeviceId'), CborString(senderDeviceId)),
      MapEntry(CborString('senderDeviceName'), CborString(senderDeviceName)),
      MapEntry(
          CborString('sentAt'), CborSmallInt(sentAt.millisecondsSinceEpoch)),
      MapEntry(
        CborString('notes'),
        CborList.of(notes.map((n) => CborBytes(n.toCbor())).toList()),
      ),
    ]);
    return Uint8List.fromList(cborEncode(map));
  }

  factory SyncBundle.fromCbor(Uint8List bytes) {
    final cborVal = cborDecode(bytes);
    final map = cborVal.toObject() as Map<dynamic, dynamic>;

    final rawNotes = map['notes'] as List<dynamic>;
    final noteEntries = rawNotes.map((n) {
      final bytes = n is Uint8List ? n : Uint8List.fromList(n as List<int>);
      return SyncNoteEntry.fromCbor(bytes);
    }).toList();

    return SyncBundle(
      protocolVersion: map['protocolVersion'] as String,
      senderDeviceId: map['senderDeviceId'] as String,
      senderDeviceName: map['senderDeviceName'] as String,
      sentAt: DateTime.fromMillisecondsSinceEpoch(map['sentAt'] as int),
      notes: noteEntries,
    );
  }

  static String computeChecksum(SyncBundle bundle) {
    final bytes = bundle.toCbor();
    return sha256.convert(bytes).toString();
  }

  static bool verifyChecksum(SyncBundle bundle, String expectedChecksum) {
    return computeChecksum(bundle) == expectedChecksum;
  }

  static List<Uint8List> splitIntoChunks(
    Uint8List data, {
    int chunkSize = 64,
  }) {
    final chunks = <Uint8List>[];
    for (var i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize > data.length) ? data.length : i + chunkSize;
      chunks.add(data.sublist(i, end));
    }
    return chunks;
  }

  static Uint8List reassembleChunks(List<Uint8List> chunks) {
    final totalLength = chunks.fold<int>(0, (sum, c) => sum + c.length);
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }
}

/// Header sent before the bundle to announce size and checksum.
class SyncHeader {
  const SyncHeader({
    required this.bundleSizeBytes,
    required this.checksum,
    required this.noteCount,
  });

  final int bundleSizeBytes;
  final String checksum;
  final int noteCount;

  Uint8List toCbor() {
    final map = CborMap.fromEntries([
      MapEntry(CborString('bundleSizeBytes'), CborSmallInt(bundleSizeBytes)),
      MapEntry(CborString('checksum'), CborString(checksum)),
      MapEntry(CborString('noteCount'), CborSmallInt(noteCount)),
    ]);
    return Uint8List.fromList(cborEncode(map));
  }

  factory SyncHeader.fromCbor(Uint8List bytes) {
    final map = cborDecode(bytes).toObject() as Map<dynamic, dynamic>;
    return SyncHeader(
      bundleSizeBytes: map['bundleSizeBytes'] as int,
      checksum: map['checksum'] as String,
      noteCount: map['noteCount'] as int,
    );
  }
}

/// Acknowledgment sent by receiver after processing a bundle.
class SyncAck {
  const SyncAck({
    required this.receivedNoteIds,
    required this.rejectedNoteIds,
  });

  final List<String> receivedNoteIds;
  final List<String> rejectedNoteIds;

  Uint8List toCbor() {
    final map = CborMap.fromEntries([
      MapEntry(
        CborString('receivedNoteIds'),
        CborList.of(receivedNoteIds.map(CborString.new).toList()),
      ),
      MapEntry(
        CborString('rejectedNoteIds'),
        CborList.of(rejectedNoteIds.map(CborString.new).toList()),
      ),
    ]);
    return Uint8List.fromList(cborEncode(map));
  }

  factory SyncAck.fromCbor(Uint8List bytes) {
    final map = cborDecode(bytes).toObject() as Map<dynamic, dynamic>;
    return SyncAck(
      receivedNoteIds: (map['receivedNoteIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      rejectedNoteIds: (map['rejectedNoteIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }
}
