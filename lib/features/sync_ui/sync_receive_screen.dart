import 'package:flutter/material.dart';

/// Sync receive screen — discoverable toggle + incoming requests.
class SyncReceiveScreen extends StatefulWidget {
  const SyncReceiveScreen({super.key});

  @override
  State<SyncReceiveScreen> createState() => _SyncReceiveScreenState();
}

class _SyncReceiveScreenState extends State<SyncReceiveScreen> {
  bool _isDiscoverable = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                _isDiscoverable
                    ? 'Other devices can find this phone'
                    : 'Other devices cannot find this phone',
                style: theme.textTheme.bodySmall,
              ),
              secondary: Icon(
                _isDiscoverable ? Icons.visibility : Icons.visibility_off,
                color: _isDiscoverable
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              value: _isDiscoverable,
              onChanged: (value) {
                setState(() => _isDiscoverable = value);
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
                        'Waiting for incoming connections...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
