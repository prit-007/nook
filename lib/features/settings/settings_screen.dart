import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Settings root screen — grouped list.
/// Full implementation in Phase 3/6.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _section(
            'Appearance',
            [
              _tile(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                onTap: () => context.push('/settings/appearance'),
              ),
            ],
          ),
          _section(
            'Security',
            [
              _tile(
                icon: Icons.lock_outline,
                title: 'Security',
                onTap: () => context.push('/settings/security'),
              ),
            ],
          ),
          _section(
            'Storage & Sync',
            [
              _tile(
                icon: Icons.storage_outlined,
                title: 'Storage & Backup',
                onTap: () => context.push('/settings/storage'),
              ),
              _tile(
                icon: Icons.devices_outlined,
                title: 'Sync Devices',
                onTap: () => context.push('/settings/sync-devices'),
              ),
            ],
          ),
          _section(
            'About',
            [
              _tile(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => context.push('/settings/about'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
