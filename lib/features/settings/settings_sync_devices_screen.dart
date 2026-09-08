import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/talker_provider.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../data/repositories/sync_log_repository.dart';
import '../../sync/sync_orchestrator.dart';
import '../../sync/transport/sync_transport.dart';

class SettingsSyncDevicesScreen extends ConsumerStatefulWidget {
  const SettingsSyncDevicesScreen({super.key});

  @override
  ConsumerState<SettingsSyncDevicesScreen> createState() =>
      _SettingsSyncDevicesScreenState();
}

class _SettingsSyncDevicesScreenState
    extends ConsumerState<SettingsSyncDevicesScreen> {
  late Future _logsFuture;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseProvider);
    _logsFuture = SyncLogRepository(db).getRecentLogs(limit: 30);
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncOrchestratorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync Devices')),
      body: Column(
        children: [
          if (syncState.selectedDevice != null)
            _ConnectedDeviceCard(
              device: syncState.selectedDevice!,
              onDisconnect: () {
                nookLog(
                  NookLogKey.sync,
                  'Disconnected from ${syncState.selectedDevice!.deviceName}',
                  LogLevel.info,
                );
                ref.read(syncOrchestratorProvider.notifier).stop();
              },
            ),
          Expanded(
            child: FutureBuilder(
              future: _logsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Failed to load sync history'),
                  );
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const Center(
                    child: Text('No sync history yet'),
                  );
                }

                final devices = <String, _DeviceSummary>{};
                for (final log in logs) {
                  devices.putIfAbsent(
                    log.deviceId,
                    () => _DeviceSummary(
                      deviceId: log.deviceId,
                      deviceName: log.deviceName,
                    ),
                  );
                  devices[log.deviceId]!.lastSync = log.timestamp;
                  devices[log.deviceId]!.syncCount++;
                }

                final deviceList = devices.values.toList()
                  ..sort((a, b) => b.lastSync.compareTo(a.lastSync));

                return ListView.builder(
                  padding: EdgeInsets.only(
                    bottom: DockSafeArea.bottomOf(context) + 16,
                  ),
                  itemCount: deviceList.length,
                  itemBuilder: (context, index) {
                    final device = deviceList[index];
                    return ListTile(
                      leading: const HugeIcon(
                          icon: HugeIcons.strokeRoundedSmartPhone01),
                      title: Text(device.deviceName),
                      subtitle: Text(
                        '${device.syncCount} notes synced · '
                        '${_formatTime(device.lastSync)}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ConnectedDeviceCard extends StatelessWidget {
  const _ConnectedDeviceCard({
    required this.device,
    required this.onDisconnect,
  });

  final SyncDevice device;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedSmartPhone02,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(device.deviceName),
        subtitle: const Text('Connected'),
        trailing: TextButton(
          onPressed: onDisconnect,
          child: const Text('Disconnect'),
        ),
      ),
    );
  }
}

class _DeviceSummary {
  _DeviceSummary({
    required this.deviceId,
    required this.deviceName,
  });

  final String deviceId;
  final String deviceName;
  late DateTime lastSync;
  int syncCount = 0;
}
