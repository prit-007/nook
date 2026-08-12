import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../sync/sync_orchestrator.dart';

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
                      syncState.phase == SyncPhase.sending
                          ? LucideIcons.send
                          : LucideIcons.download,
                      size: 40,
                      color: scheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  syncState.phase == SyncPhase.sending
                      ? 'Beaming Notes...'
                      : 'Receiving Notes...',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  syncState.phase == SyncPhase.sending
                      ? '${syncState.sentCount} of ${syncState.totalCount} sent'
                      : '${syncState.receivedCount} received',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else if (syncState.phase == SyncPhase.complete) ...[
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
              ] else if (syncState.phase == SyncPhase.error) ...[
                Icon(LucideIcons.circleAlert, size: 80, color: scheme.error),
                const SizedBox(height: 24),
                const Text(
                  'Transfer Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  syncState.error ?? 'Connection dropped.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 48),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss'),
                ),
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
}
