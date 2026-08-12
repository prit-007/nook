import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

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
    final scheme = theme.colorScheme;
    final syncState = ref.watch(syncOrchestratorProvider);
    final isDiscoverable = syncState.phase == SyncPhase.receiving ||
        syncState.phase == SyncPhase.resolving ||
        syncState.phase == SyncPhase.complete;

    _shouldStopOnDispose = syncState.phase == SyncPhase.receiving ||
        syncState.phase == SyncPhase.resolving;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Receive Notes',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: SwitchListTile.adaptive(
              title: const Text(
                'Make this device visible',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isDiscoverable
                    ? 'Other devices can find this phone'
                    : 'Other devices cannot find this phone',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              secondary: Icon(
                isDiscoverable ? LucideIcons.eye : LucideIcons.eyeOff,
                color:
                    isDiscoverable ? scheme.primary : scheme.onSurfaceVariant,
              ),
              activeThumbColor: scheme.primary,
              value: isDiscoverable,
              onChanged: (value) {
                HapticFeedback.lightImpact();
                if (value) {
                  ref
                      .read(syncOrchestratorProvider.notifier)
                      .startAdvertising();
                } else {
                  ref.read(syncOrchestratorProvider.notifier).stop();
                }
              },
            ),
          ),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                LucideIcons.smartphone,
                color: scheme.primary,
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
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (syncState.pendingPairing != null) ...[
            const SizedBox(height: 24),
            Material(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Incoming pairing request',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${syncState.pendingPairing!.remoteDeviceName} wants to '
                      'connect. Confirm this code matches the one shown on '
                      'their device.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        syncState.pendingPairing!.pairingCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => ref
                                .read(syncOrchestratorProvider.notifier)
                                .rejectPairing(),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => ref
                                .read(syncOrchestratorProvider.notifier)
                                .confirmPairing(),
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                        color: scheme.onSurfaceVariant,
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
            ...syncState.conflicts.map(
              (conflict) => ConflictCard(
                noteTitle: conflict.incoming.noteFields['title'] as String? ??
                    'Untitled',
                localDeviceName: conflict.localDeviceName,
                remoteDeviceName: conflict.remoteDeviceName,
                onResolved: (choice) {
                  ref
                      .read(syncOrchestratorProvider.notifier)
                      .resolveConflict(conflict, choice);
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
                    LucideIcons.checkCircle,
                    size: 64,
                    color: scheme.primary,
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
                      color: scheme.onSurfaceVariant,
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
                    LucideIcons.circleAlert,
                    size: 64,
                    color: scheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    syncState.error!,
                    style: TextStyle(color: scheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
