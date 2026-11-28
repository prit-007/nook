/// Feature flag gating the experimental CRDT spike (`--dart-define=NOOK_CRDT_SPIKE=true`).
///
/// Kept strictly isolated from the production sync path (`lib/sync/protocol/*`)
/// per Phase 2.3 decision: do not migrate the AppFlowy document model yet.
const bool kEnableCrdtSpike = bool.fromEnvironment('NOOK_CRDT_SPIKE');

/// Minimal Last-Write-Wins (LWW) register with Lamport clock tie-breaking
/// for evaluating CRDT convergence properties.
class LwwRegister<T> {
  LwwRegister(this.value, {required this.timestamp, required this.replicaId});

  final T value;
  final int timestamp;
  final String replicaId;

  LwwRegister<T> merge(LwwRegister<T> other) {
    if (other.timestamp > timestamp) return other;
    if (other.timestamp < timestamp) return this;
    return other.replicaId.compareTo(replicaId) > 0 ? other : this;
  }
}

/// Experimental Grow-Only / LWW-Element-Set for evaluating block-set CRDTs.
class LwwElementSet<T> {
  final Map<T, LwwRegister<bool>> _state = {};

  void add(T element, {required int timestamp, required String replicaId}) {
    final incoming = LwwRegister<bool>(
      true,
      timestamp: timestamp,
      replicaId: replicaId,
    );
    final current = _state[element];
    _state[element] = current == null ? incoming : current.merge(incoming);
  }

  void remove(T element, {required int timestamp, required String replicaId}) {
    final incoming = LwwRegister<bool>(
      false,
      timestamp: timestamp,
      replicaId: replicaId,
    );
    final current = _state[element];
    _state[element] = current == null ? incoming : current.merge(incoming);
  }

  Set<T> get elements => {
        for (final entry in _state.entries)
          if (entry.value.value) entry.key,
      };

  void mergeFrom(LwwElementSet<T> other) {
    for (final entry in other._state.entries) {
      final current = _state[entry.key];
      _state[entry.key] =
          current == null ? entry.value : current.merge(entry.value);
    }
  }
}
