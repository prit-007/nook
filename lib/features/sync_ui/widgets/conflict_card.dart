import 'package:flutter/material.dart';

/// Conflict resolution card — shown when the same note was edited on both devices.
class ConflictCard extends StatelessWidget {
  const ConflictCard({
    super.key,
    required this.noteTitle,
    required this.localDeviceName,
    required this.remoteDeviceName,
    this.onResolved,
  });

  final String noteTitle;
  final String localDeviceName;
  final String remoteDeviceName;
  final void Function(String choice)? onResolved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conflict: $noteTitle',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This note was edited on both $localDeviceName and $remoteDeviceName.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => _resolve(context, 'local'),
              child: const Text('Keep this device'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _resolve(context, 'remote'),
              child: const Text('Keep incoming'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _resolve(context, 'both'),
              child: const Text('Keep both'),
            ),
          ],
        ),
      ),
    );
  }

  void _resolve(BuildContext context, String choice) {
    if (onResolved != null) {
      onResolved!(choice);
    } else {
      Navigator.of(context).pop(choice);
    }
  }
}
