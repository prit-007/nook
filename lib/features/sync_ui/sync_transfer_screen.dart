import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../sync/sync_orchestrator.dart';
import '../../sync/transport/sync_transport.dart';

class SyncTransferScreen extends ConsumerWidget {
  const SyncTransferScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final syncState = ref.watch(syncOrchestratorProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient background gradient.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    scheme.primaryContainer.withValues(alpha: 0.3),
                    scheme.surface,
                  ],
                  radius: 1.5,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _buildStateContent(context, scheme, syncState),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateContent(
    BuildContext context,
    ColorScheme scheme,
    SyncOrchestratorState syncState,
  ) {
    if (syncState.phase == SyncPhase.sending ||
        syncState.phase == SyncPhase.receiving) {
      return _transferring(scheme, syncState);
    } else if (syncState.phase == SyncPhase.complete) {
      return _complete(context, scheme, syncState);
    } else if (syncState.phase == SyncPhase.error) {
      return _failure(context, scheme, syncState);
    } else {
      return _establishing(scheme);
    }
  }

  Widget _establishing(ColorScheme scheme) {
    return Column(
      key: const ValueKey('establishing'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          child: CircularProgressIndicator(
            strokeWidth: 4,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Establishing Link...',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _transferring(
    ColorScheme scheme,
    SyncOrchestratorState syncState,
  ) {
    final sending = syncState.phase == SyncPhase.sending;
    final progress = syncState.totalCount > 0
        ? syncState.sentCount / syncState.totalCount
        : 0.0;

    return Column(
      key: const ValueKey('transferring'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Fluid, animated progress ring — the value eases toward the actual
        // transferred count instead of jumping.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: progress),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 12,
                    backgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    color: scheme.primary,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: HugeIcon(
                    icon: sending
                        ? HugeIcons.strokeRoundedSendToMobile
                        : HugeIcons.strokeRoundedDownload01,
                    size: 48,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 48),
        Text(
          sending ? 'Beaming Notes...' : 'Receiving Notes...',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            sending
                ? '${syncState.sentCount} of ${syncState.totalCount} sent'
                : '${syncState.receivedCount} received',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _complete(
    BuildContext context,
    ColorScheme scheme,
    SyncOrchestratorState syncState,
  ) {
    return Column(
      key: const ValueKey('complete'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.3),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
              size: 80,
              color: scheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'Transfer Complete',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${syncState.sentCount + syncState.receivedCount} notes transferred safely.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 56),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ],
    );
  }

  /// Outcome-specific failure card. Deliberate rejections are amber and
  /// dismiss-only; timeouts/connection losses offer a retry; unknown failures
  /// keep the generic red treatment. Rendered as a frosted-glass sheet.
  Widget _failure(
    BuildContext context,
    ColorScheme scheme,
    SyncOrchestratorState syncState,
  ) {
    final outcome = syncState.outcome;
    final message = syncState.error ?? 'Connection dropped.';

    List<List<dynamic>> icon;
    Color alertColor;
    Color alertBackground;
    String title;
    bool showRetry;

    switch (outcome) {
      case SyncOutcomeCategory.rejected:
        icon = HugeIcons.strokeRoundedShieldBan;
        alertColor = const Color(0xFFB26A00);
        alertBackground = const Color(0x1AB26A00);
        title = 'Transfer Declined';
        showRetry = false;
      case SyncOutcomeCategory.timedOut:
        icon = HugeIcons.strokeRoundedHourglass;
        alertColor = const Color(0xFF8A6D00);
        alertBackground = const Color(0x1A8A6D00);
        title = 'Transfer Timed Out';
        showRetry = true;
      case SyncOutcomeCategory.connectionLost:
        icon = HugeIcons.strokeRoundedWifiOff01;
        alertColor = const Color(0xFF8A6D00);
        alertBackground = const Color(0x1A8A6D00);
        title = 'Connection Lost';
        showRetry = true;
      case SyncOutcomeCategory.cancelled:
        icon = HugeIcons.strokeRoundedBlockGame;
        alertColor = scheme.onSurfaceVariant;
        alertBackground = scheme.surfaceContainerHighest;
        title = 'Transfer Cancelled';
        showRetry = false;
      case SyncOutcomeCategory.protocol:
      case SyncOutcomeCategory.internal:
      case null:
        icon = HugeIcons.strokeRoundedAlertCircle;
        alertColor = scheme.error;
        alertBackground = scheme.errorContainer.withValues(alpha: 0.4);
        title = 'Transfer Failed';
        showRetry = false;
    }

    return ClipRRect(
      key: const ValueKey('failure'),
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: alertBackground.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: alertColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(icon: icon, size: 64, color: alertColor),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: alertColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  if (showRetry) ...[
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: alertColor,
                          foregroundColor: scheme.surface,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'Try Again',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: alertColor.withValues(alpha: 0.5),
                        ),
                        foregroundColor: alertColor,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Dismiss',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
