import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/sync_orchestrator.dart';
import 'widgets/conflict_card.dart';

/// Sync receive screen — discoverable toggle + incoming requests.
class SyncReceiveScreen extends ConsumerStatefulWidget {
  const SyncReceiveScreen({super.key});

  @override
  ConsumerState<SyncReceiveScreen> createState() => _SyncReceiveScreenState();
}

class _SyncReceiveScreenState extends ConsumerState<SyncReceiveScreen> {
  SyncOrchestrator? _notifier;
  bool _shouldStopOnDispose = false;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(syncOrchestratorProvider.notifier);
  }

  @override
  void dispose() {
    if (_shouldStopOnDispose) {
      _notifier?.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncState = ref.watch(syncOrchestratorProvider);
    final isDiscoverable = syncState.phase == SyncPhase.receiving ||
        syncState.phase == SyncPhase.resolving ||
        syncState.phase == SyncPhase.complete;

    _shouldStopOnDispose = syncState.phase == SyncPhase.receiving ||
        syncState.phase == SyncPhase.resolving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Notes'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Make this device visible'),
              subtitle: Text(
                isDiscoverable
                    ? 'Other devices can find this phone'
                    : 'Other devices cannot find this phone',
                style: theme.textTheme.bodySmall,
              ),
              secondary: Icon(
                isDiscoverable ? Icons.visibility : Icons.visibility_off,
                color: isDiscoverable
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              value: isDiscoverable,
              onChanged: (value) {
                if (value) {
                  ref
                      .read(syncOrchestratorProvider.notifier)
                      .startAdvertising();
                } else {
                  ref.read(syncOrchestratorProvider.notifier).stop();
                }
              },
            ),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Device',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        isDiscoverable
                            ? 'Waiting for incoming connections...'
                            : 'Not visible to other devices',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (syncState.phase == SyncPhase.receiving) ...[
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Receiving notes...',
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (syncState.receivedCount > 0)
                      Text(
                        '${syncState.receivedCount} notes received',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (syncState.phase == SyncPhase.resolving &&
                syncState.conflicts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Conflicts (${syncState.conflicts.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: syncState.conflicts.length,
                  itemBuilder: (context, index) {
                    final conflict = syncState.conflicts[index];
                    return ConflictCard(
                      noteTitle:
                          conflict.incoming.noteFields['title'] as String? ??
                              'Untitled',
                      localDeviceName: conflict.localDeviceName,
                      remoteDeviceName: conflict.remoteDeviceName,
                      onResolved: (choice) {
                        ref
                            .read(syncOrchestratorProvider.notifier)
                            .resolveConflict(conflict, choice);
                      },
                    );
                  },
                ),
              ),
            ],
            if (syncState.phase == SyncPhase.complete) ...[
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sync complete!',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${syncState.receivedCount} notes received',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (syncState.error != null) ...[
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      syncState.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
