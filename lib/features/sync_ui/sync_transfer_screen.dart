import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/sync_orchestrator.dart';

/// Sync transfer progress screen — shows real-time transfer status.
class SyncTransferScreen extends ConsumerWidget {
  const SyncTransferScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncState = ref.watch(syncOrchestratorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncState.phase == SyncPhase.sending) ...[
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: syncState.totalCount > 0
                        ? syncState.sentCount / syncState.totalCount
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sending notes...',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${syncState.sentCount} of ${syncState.totalCount} notes sent',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: syncState.totalCount > 0
                      ? syncState.sentCount / syncState.totalCount
                      : 0,
                ),
              ] else if (syncState.phase == SyncPhase.receiving) ...[
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Receiving notes...',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${syncState.receivedCount} notes received',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else if (syncState.phase == SyncPhase.complete) ...[
                Icon(
                  Icons.check_circle,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Transfer complete!',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${syncState.sentCount + syncState.receivedCount} notes transferred',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else if (syncState.phase == SyncPhase.error) ...[
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Transfer failed',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  syncState.error ?? 'Unknown error',
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Preparing transfer...',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  ref.read(syncOrchestratorProvider.notifier).stop();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
