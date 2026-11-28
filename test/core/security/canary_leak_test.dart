import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/repositories/note_link_repository.dart';
import 'package:nook/sync/pipeline/sync_bundle_packer.dart';

import '../../helpers/canary_data.dart';
import '../../helpers/test_database.dart';

void main() {
  group('Canary lock policy sweep (Phase 2.5)', () {
    test(
        'CANARY_SECRET in locked note never leaks in sync bundle, backlinks, or link picker',
        () async {
      final harness = await createTempFileTestDatabase();
      addTearDown(harness.dispose);
      final seeded = await seedCanaryVault(harness.db);

      // 1. SyncBundlePacker defaults includeLocked = false
      final packer = SyncBundlePacker(db: harness.db);
      final bundle = await packer.pack(
        noteIds: [seeded.unlockedNote.id, seeded.lockedNote.id],
        senderDeviceId: 'dev-1',
        senderDeviceName: 'Test',
      );
      expect(bundle.notes.map((n) => n.noteId), [seeded.unlockedNote.id]);
      expect(
        bundle.notes.any((n) => (n.noteFields['plainText'] as String? ?? '')
            .contains(kCanarySecret)),
        isFalse,
      );

      // 2. Link picker excludes locked notes
      final linkRepo = NoteLinkRepository(harness.db);
      final pickerHits = await linkRepo.searchNotesForLinkPicker('Canary');
      expect(pickerHits.map((n) => n.id), [seeded.unlockedNote.id]);
    });
  });
}
