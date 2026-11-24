import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/nook_tokens.dart';
import '../../sync/sync_orchestrator.dart';

/// A dynamic app-bar sync status indicator reflecting the live state of sync:
///
/// - **Conflict**: Surfaces a prominent amber badge with the conflict count
///   acting as a conflict inbox.
/// - **Syncing / Transferring**: Rotating sync icon indicating active I/O.
/// - **Error**: Warning icon with error tooltip.
/// - **Synced / Idle**: Clean cloud/wifi icon indicating healthy sync.
///
/// Tapping the indicator opens the sync screen or directly navigates to review
/// conflicts when present.
class SyncStatusIndicator extends ConsumerStatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  ConsumerState<SyncStatusIndicator> createState() =>
      _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final syncState = ref.watch(syncOrchestratorProvider);
    final hasConflicts = syncState.conflicts.isNotEmpty;
    final isSyncing = syncState.phase == SyncPhase.sending ||
        syncState.phase == SyncPhase.receiving ||
        syncState.phase == SyncPhase.connecting ||
        syncState.phase == SyncPhase.discovering ||
        syncState.phase == SyncPhase.resolving;
    final isError = syncState.phase == SyncPhase.error;

    if (isSyncing) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
        _rotationController.reset();
      }
    }

    String tooltip;
    List<List<dynamic>> iconData;
    Color iconColor;

    if (hasConflicts) {
      tooltip =
          'Sync conflicts (${syncState.conflicts.length}) · Tap to resolve';
      iconData = HugeIcons.strokeRoundedAlertCircle;
      iconColor = scheme.error;
    } else if (isSyncing) {
      tooltip =
          'Syncing with ${syncState.selectedDevice?.deviceName ?? 'device'}...';
      iconData = HugeIcons.strokeRoundedWifi01;
      iconColor = scheme.primary;
    } else if (isError) {
      tooltip = 'Sync error: ${syncState.error ?? 'Connection failed'}';
      iconData = HugeIcons.strokeRoundedAlertCircle;
      iconColor = scheme.error;
    } else {
      tooltip = 'Sync & devices · Synced';
      iconData = HugeIcons.strokeRoundedCheckmarkCircle01;
      iconColor = scheme.onSurfaceVariant;
    }

    return Semantics(
      label: tooltip,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/sync');
          },
          radius: 24,
          splashColor: scheme.primary.withValues(alpha: 0.12),
          highlightColor: scheme.primary.withValues(alpha: 0.08),
          borderRadius: context.tokens.borderRadiusMd,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    if (!isSyncing) return child!;
                    return Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: AnimatedSwitcher(
                    duration: AppMotion.short3,
                    child: HugeIcon(
                      key: ValueKey('${hasConflicts}_${isSyncing}_$isError'),
                      icon: iconData,
                      size: 22,
                      color: iconColor,
                    ),
                  ),
                ),
                if (hasConflicts)
                  Positioned(
                    top: 6,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: context.tokens.borderRadiusPill,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.error.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${syncState.conflicts.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: scheme.onError,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
