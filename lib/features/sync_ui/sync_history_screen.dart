import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/sync_log_repository.dart';
import '../../data/tables/sync_log.dart';

/// Sync history screen — past transfers.
class SyncHistoryScreen extends ConsumerWidget {
  const SyncHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final repo = SyncLogRepository(db);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear History',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear History'),
                  content: const Text(
                    'Are you sure you want to clear all sync history?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await repo.clearHistory();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<SyncLogData>>(
        future: repo.getRecentLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sync history yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: Icon(_actionIcon(log.action)),
                title: Text(_actionLabel(log.action)),
                subtitle: Text('${log.deviceName} - ${log.noteId}'),
                trailing: Text(
                  DateFormat.yMMMd().add_jm().format(log.timestamp),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _actionIcon(SyncAction action) {
    switch (action) {
      case SyncAction.sent:
        return Icons.send;
      case SyncAction.received:
        return Icons.download;
      case SyncAction.conflict:
        return Icons.warning_amber_rounded;
    }
  }

  String _actionLabel(SyncAction action) {
    switch (action) {
      case SyncAction.sent:
        return 'Sent';
      case SyncAction.received:
        return 'Received';
      case SyncAction.conflict:
        return 'Conflict';
    }
  }
}
