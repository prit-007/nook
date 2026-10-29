import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/pipeline/sync_progress_tracker.dart';

void main() {
  group('SyncProgressTracker', () {
    late SyncProgressTracker tracker;

    setUp(() {
      tracker = SyncProgressTracker();
    });

    test('initial stats are idle with 0 progress', () {
      final stats = tracker.stats;
      expect(stats.stage, SyncStage.idle);
      expect(stats.bytesTransferred, 0);
      expect(stats.totalBytes, 0);
      expect(stats.itemsTransferred, 0);
      expect(stats.totalItems, 0);
      expect(stats.byteProgress, 0.0);
      expect(stats.itemProgress, 0.0);
      expect(stats.bytesPerSecond, 0.0);
      expect(stats.estimatedTimeRemaining, isNull);
    });

    test('start initializes totalItems and totalBytes', () {
      tracker.start(totalItems: 5, totalBytes: 10000);
      final stats = tracker.stats;
      expect(stats.stage, SyncStage.connecting);
      expect(stats.totalItems, 5);
      expect(stats.totalBytes, 10000);
      expect(stats.itemsTransferred, 0);
      expect(stats.bytesTransferred, 0);
    });

    test('setStage updates stage and description', () {
      tracker.setStage(SyncStage.packaging, description: 'Packing 5 notes...');
      expect(tracker.stats.stage, SyncStage.packaging);
      expect(tracker.stats.stageDescription, 'Packing 5 notes...');
    });

    test('updateItem tracks current item name and count', () {
      tracker.start(totalItems: 3, totalBytes: 6000);
      tracker.updateItem(itemName: 'Grocery List', itemIndex: 1);

      expect(tracker.stats.itemsTransferred, 1);
      expect(tracker.stats.currentItemName, 'Grocery List');
      expect(tracker.stats.itemProgress, closeTo(1 / 3, 0.001));
    });

    test('updateBytes computes speed and ETA over time', () {
      final t0 = DateTime(2026, 10, 29, 12, 0, 0);
      tracker.start(totalItems: 2, totalBytes: 1000000, startTime: t0);

      // 1 second later, 500,000 bytes transferred -> 500,000 B/s -> ETA 1s
      final t1 = t0.add(const Duration(seconds: 1));
      tracker.updateBytes(500000, now: t1);

      final stats = tracker.stats;
      expect(stats.bytesTransferred, 500000);
      expect(stats.byteProgress, 0.5);
      expect(stats.bytesPerSecond, closeTo(500000.0, 100.0));
      expect(stats.estimatedTimeRemaining?.inSeconds, 1);
      expect(stats.formattedSpeed, contains('KB/s'));
      expect(stats.formattedEta, '~1s remaining');
      expect(stats.formattedBytes, contains('of'));
    });

    test('formattedSpeed formats B/s, KB/s, and MB/s appropriately', () {
      final t0 = DateTime(2026, 10, 29, 12, 0, 0);
      tracker.start(totalItems: 1, totalBytes: 10000000, startTime: t0);

      // 2MB transferred in 1 second -> ~2 MB/s
      final t1 = t0.add(const Duration(seconds: 1));
      tracker.updateBytes(2 * 1024 * 1024, now: t1);

      expect(tracker.stats.formattedSpeed, '2.0 MB/s');
    });

    test('complete marks stage as complete with 100% progress', () {
      tracker.start(totalItems: 4, totalBytes: 4000);
      tracker.complete();

      expect(tracker.stats.stage, SyncStage.complete);
      expect(tracker.stats.byteProgress, 1.0);
      expect(tracker.stats.itemProgress, 1.0);
    });

    test('fail marks stage as failed with error description', () {
      tracker.start(totalItems: 2, totalBytes: 2000);
      tracker.fail('Connection dropped by peer');

      expect(tracker.stats.stage, SyncStage.failed);
      expect(tracker.stats.stageDescription, 'Connection dropped by peer');
    });
  });
}
