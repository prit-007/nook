import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (syncState.phase == SyncPhase.sending ||
                  syncState.phase == SyncPhase.receiving) ...[
                _transferring(scheme, syncState),
              ] else if (syncState.phase == SyncPhase.complete) ...[
                _complete(context, scheme, syncState),
              ] else if (syncState.phase == SyncPhase.error) ...[
                ..._failure(context, scheme, syncState),
              ] else ...[
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(strokeWidth: 4),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Establishing Link...',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _transferring(ColorScheme scheme, SyncOrchestratorState syncState) {
    final sending = syncState.phase == SyncPhase.sending;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: syncState.totalCount > 0
                    ? syncState.sentCount / syncState.totalCount
                    : null,
                strokeWidth: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
                strokeCap: StrokeCap.round,
              ),
            ),
            Icon(
              sending ? LucideIcons.send : LucideIcons.download,
              size: 40,
              color: scheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          sending ? 'Beaming Notes...' : 'Receiving Notes...',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sending
              ? '${syncState.sentCount} of ${syncState.totalCount} sent'
              : '${syncState.receivedCount} received',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
            fontWeight: FontWeight.w500,
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
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            LucideIcons.checkCircle,
            size: 64,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Transfer Complete',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${syncState.sentCount + syncState.receivedCount} notes transferred safely.',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 48),
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 48,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  /// Renders the outcome-specific failure state. Deliberate rejections are
  /// amber and dismiss-only; timeouts/connection losses offer a retry; unknown
  /// failures keep the generic red treatment.
  List<Widget> _failure(
    BuildContext context,
    ColorScheme scheme,
    SyncOrchestratorState syncState,
  ) {
    final outcome = syncState.outcome;
    final message = syncState.error ?? 'Connection dropped.';

    switch (outcome) {
      case SyncOutcomeCategory.rejected:
        return _failureContent(
          context: context,
          scheme: scheme,
          icon: LucideIcons.shieldBan,
          color: const Color(0xFFB26A00),
          background: const Color(0x1AB26A00),
          title: 'Transfer Declined',
          message: message,
          showRetry: false,
        );
      case SyncOutcomeCategory.timedOut:
        return _failureContent(
          context: context,
          scheme: scheme,
          icon: LucideIcons.hourglass,
          color: const Color(0xFF8A6D00),
          background: const Color(0x1A8A6D00),
          title: 'Transfer Timed Out',
          message: message,
          showRetry: true,
        );
      case SyncOutcomeCategory.connectionLost:
        return _failureContent(
          context: context,
          scheme: scheme,
          icon: LucideIcons.wifiOff,
          color: const Color(0xFF8A6D00),
          background: const Color(0x1A8A6D00),
          title: 'Connection Lost',
          message: message,
          showRetry: true,
        );
      case SyncOutcomeCategory.cancelled:
        return _failureContent(
          context: context,
          scheme: scheme,
          icon: LucideIcons.ban,
          color: scheme.onSurfaceVariant,
          background: scheme.surfaceContainerHighest,
          title: 'Transfer Cancelled',
          message: message,
          showRetry: false,
        );
      case SyncOutcomeCategory.protocol:
      case SyncOutcomeCategory.internal:
      case null:
        return _failureContent(
          context: context,
          scheme: scheme,
          icon: LucideIcons.circleAlert,
          color: scheme.error,
          background: scheme.errorContainer.withValues(alpha: 0.25),
          title: 'Transfer Failed',
          message: message,
          showRetry: false,
        );
    }
  }

  List<Widget> _failureContent({
    required BuildContext context,
    required ColorScheme scheme,
    required IconData icon,
    required Color color,
    required Color background,
    required String title,
    required String message,
    required bool showRetry,
  }) {
    return [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 64, color: color),
      ),
      const SizedBox(height: 24),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 48),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showRetry) ...[
            FilledButton(
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
          ],
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    ];
  }
}
