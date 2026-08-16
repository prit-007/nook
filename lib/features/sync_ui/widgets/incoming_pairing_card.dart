import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sync/sync_orchestrator.dart';
import 'pairing_code_field.dart';

/// Card shown when a remote device requests pairing. Used by both the receive
/// screen (mobile receiving from a desktop) and the send screen (PC accepting
/// a mobile that scanned its QR code).
class IncomingPairingCard extends ConsumerWidget {
  const IncomingPairingCard({super.key, this.onAccept, this.onReject});

  /// Optional post-confirm hook (e.g. the desktop send flow pushes notes right
  /// after the mobile pairs). [confirmPairing] is still called by the card.
  final Future<void> Function()? onAccept;

  /// Optional post-reject hook. [rejectPairing] is still called by the card.
  final Future<void> Function()? onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final syncState = ref.watch(syncOrchestratorProvider);
    final request = syncState.pendingPairing;
    if (request == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            '${request.remoteDeviceName} wants to connect',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Confirm this code matches the one shown on their device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          PairingCodeField(code: request.pairingCode),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () async {
                    await ref
                        .read(syncOrchestratorProvider.notifier)
                        .rejectPairing();
                    await onReject?.call();
                  },
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(syncOrchestratorProvider.notifier)
                        .confirmPairing();
                    await onAccept?.call();
                  },
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
