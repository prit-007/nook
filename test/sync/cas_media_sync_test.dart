import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/sync_orchestrator.dart';
import 'package:nook/sync/transport/sync_transport.dart';

class _TestSyncOrchestrator extends SyncOrchestrator {
  final MockSyncTransport _mockTransport;

  _TestSyncOrchestrator(this._mockTransport, {Directory? restoreDir}) {
    restoredAttachmentsDirectoryOverride = restoreDir;
  }

  @override
  Future<void> initializeTransport({
    SyncTransport? testTransport,
    String? localDeviceName,
    bool useTcpFallback = false,
    IdentityStore? identityStore,
    String? listenAddress,
    bool discoveryNetworkEnabled = true,
  }) async {
    await super.initializeTransport(testTransport: _mockTransport);
  }
}

Future<bool> _pollUntil(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration step = const Duration(milliseconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (await condition()) return true;
    await Future.delayed(step);
  }
  return condition();
}

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late MockSyncTransport mockTransport;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nook_cas_sync_test_');
    db = AppDatabase(NativeDatabase.memory());
    mockTransport = MockSyncTransport();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer makeContainer({required Directory restoreDir}) {
    return ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncOrchestratorProvider.overrideWith(
          () => _TestSyncOrchestrator(mockTransport, restoreDir: restoreDir),
        ),
      ],
    );
  }

  test('CAS sync deduplicates identical images across multiple notes',
      () async {
    final restoreDir = Directory('${tempDir.path}/sync-restore');
    container = makeContainer(restoreDir: restoreDir);
    final notifier = container.read(syncOrchestratorProvider.notifier);
    await notifier.initializeTransport();
    await notifier.startAdvertising();

    final sharedImageBytes =
        Uint8List.fromList(utf8.encode('identical-image-bytes-12345'));

    final bundle = SyncBundle(
      protocolVersion: '1.0',
      senderDeviceId: 'device-cas-remote',
      senderDeviceName: 'Remote Device',
      sentAt: DateTime.utc(2026, 10, 29),
      notes: [
        SyncNoteEntry(
          noteId: 'note-1',
          syncVersion: 1,
          updatedAt: DateTime.utc(2026, 10, 29, 1),
          deviceOriginId: 'device-cas-remote',
          noteFields: {
            'title': 'Note 1',
            'type': 'text',
            'plainText': 'First note',
          },
          attachments: [
            SyncAttachment(
              id: 'att-1',
              type: 'image',
              sortOrder: 0,
              bytes: sharedImageBytes,
              filePath: '/remote/path/shared.png',
            ),
          ],
        ),
        SyncNoteEntry(
          noteId: 'note-2',
          syncVersion: 1,
          updatedAt: DateTime.utc(2026, 10, 29, 2),
          deviceOriginId: 'device-cas-remote',
          noteFields: {
            'title': 'Note 2',
            'type': 'text',
            'plainText': 'Second note',
          },
          attachments: [
            SyncAttachment(
              id: 'att-2',
              type: 'image',
              sortOrder: 0,
              bytes: sharedImageBytes,
              filePath: '/remote/path/shared_copy.png',
            ),
          ],
        ),
      ],
    );

    mockTransport.emitBytesReceived(bundle.toCbor());

    final completed = await _pollUntil(() async =>
        container.read(syncOrchestratorProvider).phase == SyncPhase.complete);
    expect(completed, isTrue);

    final attachmentRepo = AttachmentRepository(db);
    final att1 = await attachmentRepo.getById('att-1');
    final att2 = await attachmentRepo.getById('att-2');
    expect(att1, isNotNull);
    expect(att2, isNotNull);

    // CAS check: both attachments should point to the exact same file path!
    expect(att1!.filePath, equals(att2!.filePath));
    expect(att1.filePath, contains('/cas/'));

    final casFile = File(att1.filePath);
    expect(await casFile.exists(), isTrue);
    expect(await casFile.readAsBytes(), orderedEquals(sharedImageBytes));

    // Verify only 1 image file was created in the CAS folder
    final casDir = Directory('${restoreDir.path}/media/cas');
    expect(casDir.existsSync(), isTrue);
    final filesInCas = casDir.listSync().whereType<File>().toList();
    expect(filesInCas.length, 1);

    // Deleting att1 should NOT delete the CAS file on disk
    await attachmentRepo.deleteAttachmentWithFiles(att1);
    expect(await casFile.exists(), isTrue);

    // Deleting att2 should now remove the CAS file on disk as no references remain
    await attachmentRepo.deleteAttachmentWithFiles(att2);
    expect(await casFile.exists(), isFalse);
  });
}
