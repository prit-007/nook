import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:crypto/crypto.dart';

import 'sync_bundle.dart';

/// Message types carried by a single sync stream transaction.
enum SyncMessageType {
  pairingRequest,
  pairingAccepted,
  pairingRejected,
  dataBundle,
  ack,
}

/// The unified wire envelope exchanged over a libp2p stream.
///
/// One envelope per stream transaction, framed as:
/// `[4-byte big-endian length N][32-byte SHA-256 of payload][N bytes payload]`
/// where N includes the 32 checksum bytes. The checksum is verified *before*
/// the CBOR payload is deserialized, preserving AGENTS.md's
/// checksum-before-deserialization guarantee (the transport's Noise layer
/// handles confidentiality/authenticity; this guards against corruption).
class SyncMessage {
  const SyncMessage({
    required this.type,
    required this.senderDeviceId,
    required this.senderDeviceName,
    this.requestId,
    this.pairingCode,
    this.bundleBytes,
    this.ack,
  });

  final SyncMessageType type;
  final String senderDeviceId;
  final String senderDeviceName;

  /// Correlation id for held-stream pairing requests.
  final String? requestId;

  /// The pairing code supplied by the initiator, for `pairingRequest` messages.
  final String? pairingCode;

  /// Raw CBOR bytes of the [SyncBundle] for `dataBundle` messages.
  final Uint8List? bundleBytes;

  /// Receiver acknowledgment for `ack` messages.
  final SyncAck? ack;

  bool get isPairing =>
      type == SyncMessageType.pairingRequest ||
      type == SyncMessageType.pairingAccepted ||
      type == SyncMessageType.pairingRejected;
}

/// Thrown when a framed envelope is malformed (truncated, trailing bytes, or
/// a payload that is not valid CBOR).
class SyncMessageFormatException implements Exception {
  const SyncMessageFormatException(this.message);
  final String message;

  @override
  String toString() => 'SyncMessageFormatException: $message';
}

/// Thrown when the SHA-256 checksum does not match the payload.
class SyncMessageChecksumException implements Exception {
  const SyncMessageChecksumException();
}

/// Encodes and decodes [SyncMessage] envelopes with SHA-256 integrity.
class SyncMessageCodec {
  const SyncMessageCodec._();

  /// Size of the framing header: 4 length bytes + 32 checksum bytes.
  static const int headerLength = 4 + 32;

  /// Maximum accepted envelope length (payload + checksum). Guards against a
  /// malicious peer advertising an enormous frame and exhausting memory.
  static const int maxFrameLength = 512 * 1024 * 1024; // 512 MB

  static Uint8List encode(SyncMessage message) {
    final payload = _encodePayload(message);
    final checksum = sha256.convert(payload).bytes;
    final length = checksum.length + payload.length;

    final out = BytesBuilder(copy: false);
    final lengthBytes = ByteData(4)..setUint32(0, length, Endian.big);
    out.add(lengthBytes.buffer.asUint8List());
    out.add(checksum);
    out.add(payload);
    return out.toBytes();
  }

  /// Decodes exactly one framed envelope from [framed].
  ///
  /// Throws [SyncMessageFormatException] on truncation/trailing bytes and
  /// [SyncMessageChecksumException] when the checksum does not match.
  static SyncMessage decode(Uint8List framed) {
    if (framed.length < headerLength) {
      throw const SyncMessageFormatException(
          'Envelope is shorter than its header');
    }

    final length = ByteData.sublistView(framed, 0, 4).getUint32(0, Endian.big);
    if (length > maxFrameLength) {
      throw SyncMessageFormatException('Envelope too large ($length bytes)');
    }
    if (framed.length < 4 + length) {
      throw const SyncMessageFormatException('Envelope payload truncated');
    }
    if (framed.length != 4 + length) {
      throw SyncMessageFormatException(
          'Envelope has ${framed.length - 4 - length} trailing bytes');
    }

    final checksum = framed.sublist(4, 36);
    final payload = framed.sublist(36, 4 + length);

    if (!_constantTimeEquals(checksum, sha256.convert(payload).bytes)) {
      throw const SyncMessageChecksumException();
    }

    return _decodePayload(Uint8List.fromList(payload));
  }

  static Uint8List _encodePayload(SyncMessage message) {
    final map = CborMap.fromEntries([
      MapEntry(CborString('type'), CborString(message.type.name)),
      MapEntry(
          CborString('senderDeviceId'), CborString(message.senderDeviceId)),
      MapEntry(
          CborString('senderDeviceName'), CborString(message.senderDeviceName)),
      if (message.requestId != null)
        MapEntry(CborString('requestId'), CborString(message.requestId!)),
      if (message.pairingCode != null)
        MapEntry(CborString('pairingCode'), CborString(message.pairingCode!)),
      if (message.bundleBytes != null)
        MapEntry(CborString('bundle'), CborBytes(message.bundleBytes!)),
      if (message.ack != null)
        MapEntry(CborString('ack'), CborBytes(message.ack!.toCbor())),
    ]);
    return Uint8List.fromList(cborEncode(map));
  }

  static SyncMessage _decodePayload(Uint8List payload) {
    CborValue decoded;
    try {
      decoded = cborDecode(payload);
    } catch (e) {
      throw SyncMessageFormatException('Payload is not valid CBOR: $e');
    }

    final map = decoded.toObject();
    if (map is! Map<dynamic, dynamic>) {
      throw const SyncMessageFormatException('Payload is not a CBOR map');
    }

    final typeName = map['type'];
    if (typeName is! String) {
      throw const SyncMessageFormatException('Missing message type');
    }

    final SyncMessageType type;
    try {
      type = SyncMessageType.values.byName(typeName);
    } catch (_) {
      throw SyncMessageFormatException('Unknown message type: $typeName');
    }

    final senderDeviceId = map['senderDeviceId'];
    final senderDeviceName = map['senderDeviceName'];
    if (senderDeviceId is! String || senderDeviceName is! String) {
      throw const SyncMessageFormatException(
          'Message is missing sender identity');
    }

    final rawRequestId = map['requestId'];
    final requestId = rawRequestId is String ? rawRequestId : null;

    final rawPairingCode = map['pairingCode'];
    final pairingCode = rawPairingCode is String ? rawPairingCode : null;

    Uint8List? bundleBytes;
    final rawBundle = map['bundle'];
    if (rawBundle is Uint8List) {
      bundleBytes = rawBundle;
    } else if (rawBundle is List<int>) {
      bundleBytes = Uint8List.fromList(rawBundle);
    }

    SyncAck? ack;
    final rawAck = map['ack'];
    if (rawAck is Uint8List) {
      ack = SyncAck.fromCbor(rawAck);
    } else if (rawAck is List<int>) {
      ack = SyncAck.fromCbor(Uint8List.fromList(rawAck));
    }

    return SyncMessage(
      type: type,
      senderDeviceId: senderDeviceId,
      senderDeviceName: senderDeviceName,
      requestId: requestId,
      pairingCode: pairingCode,
      bundleBytes: bundleBytes,
      ack: ack,
    );
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
