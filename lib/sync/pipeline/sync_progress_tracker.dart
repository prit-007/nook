import 'dart:math' as math;

enum SyncStage {
  idle,
  connecting,
  handshaking,
  packaging,
  transferring,
  restoringMedia,
  resolvingConflicts,
  finalizing,
  complete,
  failed,
}

/// Immutable snapshot of live synchronization progress, speed, and time estimates.
class SyncProgressStats {
  const SyncProgressStats({
    this.stage = SyncStage.idle,
    this.bytesTransferred = 0,
    this.totalBytes = 0,
    this.itemsTransferred = 0,
    this.totalItems = 0,
    this.bytesPerSecond = 0.0,
    this.estimatedTimeRemaining,
    this.currentItemName,
    this.stageDescription,
  });

  final SyncStage stage;
  final int bytesTransferred;
  final int totalBytes;
  final int itemsTransferred;
  final int totalItems;
  final double bytesPerSecond;
  final Duration? estimatedTimeRemaining;
  final String? currentItemName;
  final String? stageDescription;

  double get byteProgress =>
      totalBytes > 0 ? (bytesTransferred / totalBytes).clamp(0.0, 1.0) : 0.0;

  double get itemProgress =>
      totalItems > 0 ? (itemsTransferred / totalItems).clamp(0.0, 1.0) : 0.0;

  String get formattedSpeed {
    if (bytesPerSecond < 1024) {
      return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  String get formattedEta {
    if (estimatedTimeRemaining == null || bytesTransferred == 0) return '';
    final seconds = estimatedTimeRemaining!.inSeconds;
    if (seconds <= 0) return 'Almost done';
    if (seconds < 60) return '~${seconds}s remaining';
    final minutes = estimatedTimeRemaining!.inMinutes;
    return '~${minutes}m remaining';
  }

  String get formattedBytes {
    String formatSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    if (totalBytes <= 0) return formatSize(bytesTransferred);
    return '${formatSize(bytesTransferred)} of ${formatSize(totalBytes)}';
  }

  SyncProgressStats copyWith({
    SyncStage? stage,
    int? bytesTransferred,
    int? totalBytes,
    int? itemsTransferred,
    int? totalItems,
    double? bytesPerSecond,
    Duration? estimatedTimeRemaining,
    bool clearEta = false,
    String? currentItemName,
    bool clearItemName = false,
    String? stageDescription,
    bool clearStageDescription = false,
  }) {
    return SyncProgressStats(
      stage: stage ?? this.stage,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      itemsTransferred: itemsTransferred ?? this.itemsTransferred,
      totalItems: totalItems ?? this.totalItems,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      estimatedTimeRemaining: clearEta
          ? null
          : (estimatedTimeRemaining ?? this.estimatedTimeRemaining),
      currentItemName:
          clearItemName ? null : (currentItemName ?? this.currentItemName),
      stageDescription: clearStageDescription
          ? null
          : (stageDescription ?? this.stageDescription),
    );
  }
}

/// Tracks byte throughput, item progress, and computes rolling transfer speeds and ETA.
class SyncProgressTracker {
  SyncProgressTracker();

  SyncProgressStats _stats = const SyncProgressStats();
  DateTime? _startTime;
  DateTime? _lastSampleTime;
  int _lastSampleBytes = 0;

  SyncProgressStats get stats => _stats;

  void start({
    required int totalItems,
    required int totalBytes,
    DateTime? startTime,
  }) {
    final now = startTime ?? DateTime.now();
    _startTime = now;
    _lastSampleTime = now;
    _lastSampleBytes = 0;
    _stats = SyncProgressStats(
      stage: SyncStage.connecting,
      totalItems: totalItems,
      totalBytes: totalBytes,
    );
  }

  void setStage(SyncStage stage, {String? description}) {
    _stats = _stats.copyWith(
      stage: stage,
      stageDescription: description,
    );
  }

  void updateItem({required String itemName, required int itemIndex}) {
    _stats = _stats.copyWith(
      itemsTransferred: itemIndex,
      currentItemName: itemName,
    );
  }

  void updateBytes(int bytesTransferred, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final elapsedTotal =
        _startTime != null ? current.difference(_startTime!).inMilliseconds : 0;

    double speed = _stats.bytesPerSecond;
    if (elapsedTotal > 100) {
      // Calculate overall speed with rolling sample smoothing
      final overallSpeed = (bytesTransferred / (elapsedTotal / 1000.0));
      if (_lastSampleTime != null) {
        final sampleDelta = current.difference(_lastSampleTime!).inMilliseconds;
        if (sampleDelta > 300) {
          final instantSpeed =
              (bytesTransferred - _lastSampleBytes) / (sampleDelta / 1000.0);
          speed = (0.7 * instantSpeed) + (0.3 * overallSpeed);
          _lastSampleTime = current;
          _lastSampleBytes = bytesTransferred;
        } else {
          speed = overallSpeed;
        }
      } else {
        speed = overallSpeed;
      }
    }

    Duration? eta;
    if (speed > 50 && _stats.totalBytes > bytesTransferred) {
      final remainingBytes = _stats.totalBytes - bytesTransferred;
      final remainingSeconds = (remainingBytes / speed).ceil();
      eta = Duration(seconds: math.max(1, remainingSeconds));
    }

    _stats = _stats.copyWith(
      stage: SyncStage.transferring,
      bytesTransferred: bytesTransferred,
      bytesPerSecond: speed,
      estimatedTimeRemaining: eta,
    );
  }

  void complete() {
    _stats = _stats.copyWith(
      stage: SyncStage.complete,
      bytesTransferred:
          _stats.totalBytes > 0 ? _stats.totalBytes : _stats.bytesTransferred,
      itemsTransferred:
          _stats.totalItems > 0 ? _stats.totalItems : _stats.itemsTransferred,
      clearEta: true,
      clearItemName: true,
      stageDescription: 'Transfer complete',
    );
  }

  void fail(String reason) {
    _stats = _stats.copyWith(
      stage: SyncStage.failed,
      stageDescription: reason,
      clearEta: true,
    );
  }

  void reset() {
    _stats = const SyncProgressStats();
    _startTime = null;
    _lastSampleTime = null;
    _lastSampleBytes = 0;
  }
}
