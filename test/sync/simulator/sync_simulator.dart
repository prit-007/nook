import 'dart:math';

import 'package:nook/sync/protocol/merge_resolver.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';

/// Deterministic network chaos simulator for multi-peer sync convergence tests.
///
/// Injects configurable packet drops, duplicates, and out-of-order delivery
/// using a seeded [Random] instance so failures are 100% reproducible.
class SyncSimulator {
  SyncSimulator({
    int seed = 42,
    this.dropProbability = 0.15,
    this.duplicateProbability = 0.2,
  }) : _rng = Random(seed);

  final Random _rng;
  final double dropProbability;
  final double duplicateProbability;

  /// Simulates delivering [bundle] over an unreliable channel, returning a list
  /// of delivered [SyncNoteEntry] items (with possible drops, duplicates, and
  /// shuffling). A final reliable catch-up round can deliver [bundle.notes]
  /// directly to verify eventual convergence.
  List<SyncNoteEntry> simulateDelivery(SyncBundle bundle) {
    final delivered = <SyncNoteEntry>[];
    for (final entry in bundle.notes) {
      if (_rng.nextDouble() < dropProbability) {
        continue;
      }
      delivered.add(entry);
      if (_rng.nextDouble() < duplicateProbability) {
        delivered.add(entry);
      }
    }
    delivered.shuffle(_rng);
    return delivered;
  }

  /// Applies [entries] to [resolver] in order.
  Future<void> applyEntries(
    MergeResolver resolver,
    List<SyncNoteEntry> entries,
  ) async {
    for (final entry in entries) {
      await resolver.applyIncoming(entry);
    }
  }
}
