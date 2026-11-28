import 'package:flutter_test/flutter_test.dart';

import 'canary_data.dart';
import 'fake_clock.dart';
import 'test_database.dart';

void main() {
  group('Shared test harness self-test (Phase 1.1)', () {
    test('FakeClock advances deterministically', () {
      final clock = FakeClock(DateTime.utc(2026, 11, 28, 9, 0));
      expect(clock.now(), DateTime.utc(2026, 11, 28, 9, 0));
      clock.advance(const Duration(minutes: 15));
      expect(clock.now(), DateTime.utc(2026, 11, 28, 9, 15));
    });

    test('createTempTestDatabase creates isolated temp DB and cleans up',
        () async {
      final harness = await createTempFileTestDatabase();
      addTearDown(harness.dispose);

      expect(harness.db.schemaVersion, 11);
      expect(harness.file.existsSync(), isTrue);
    });

    test('CanaryData seeds unlocked and locked canary notes deterministically',
        () async {
      final harness = await createTempFileTestDatabase();
      addTearDown(harness.dispose);
      final clock = FakeClock(DateTime.utc(2026, 11, 28, 10, 0));

      final seeded = await seedCanaryVault(harness.db, clock: clock);
      expect(seeded.lockedNote.locked, isTrue);
      expect(seeded.lockedNote.plainText, contains(kCanarySecret));
      expect(seeded.unlockedNote.locked, isFalse);
    });
  });
}
