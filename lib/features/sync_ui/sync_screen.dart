import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/trusted_device_repository.dart';
import '../../sync/sync_orchestrator.dart';

final trustedDevicesProvider = FutureProvider<List<TrustedDevice>>((ref) {
  final db = ref.watch(databaseProvider);
  return TrustedDeviceRepository(db).getTrustedDevices();
});

class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final trustedDevicesAsync = ref.watch(trustedDevicesProvider);
    final syncState = ref.watch(syncOrchestratorProvider);
    final isTransferring = syncState.phase == SyncPhase.sending ||
        syncState.phase == SyncPhase.receiving;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Peer Sync',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: HugeIcon(
                icon: HugeIcons.strokeRoundedTransactionHistory,
                size: 24,
                color: scheme.onSurface),
            tooltip: 'Sync History',
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/sync/history');
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              if (isTransferring) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transfer in progress (${syncState.phase == SyncPhase.sending ? 'Sending' : 'Receiving'})',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            if (syncState.formattedSpeed.isNotEmpty)
                              Text(
                                '${syncState.formattedSpeed} · ${syncState.formattedBytes}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => context.push('/sync/transfer/active'),
                        child: const Text('View Transfer'),
                      ),
                    ],
                  ),
                ),
              ],
              Text(
                'Transfer notes directly to nearby devices over your local network. No cloud required.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              if (syncState.devices.isNotEmpty) ...[
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedWifi01,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nearby Devices (${syncState.devices.length})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...syncState.devices.map((device) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedSmartPhone01,
                          size: 22,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.deviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Ready to sync',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: () {
                            ref
                                .read(syncOrchestratorProvider.notifier)
                                .selectDevice(device);
                            context.push('/sync/send');
                          },
                          child: const Text('Send Notes'),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide = constraints.maxWidth > 500;
                  final cards = [
                    _GlassModeCard(
                      icon: HugeIcons.strokeRoundedSendToMobile,
                      title: 'Send to Device',
                      subtitle: 'Select notes and beam them across the room.',
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        context.push('/sync/send');
                      },
                    ),
                    _GlassModeCard(
                      icon: HugeIcons.strokeRoundedDownload01,
                      title: 'Receive Notes',
                      subtitle: 'Open your vault to accept incoming transfers.',
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        context.push('/sync/receive');
                      },
                    ),
                  ];
                  if (sideBySide) {
                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 20),
                        Expanded(child: cards[1]),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      cards[0],
                      const SizedBox(height: 24),
                      cards[1],
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedLaptopCheck,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trusted Devices',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              trustedDevicesAsync.when(
                data: (devices) {
                  if (devices.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedInformationCircle,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No trusted devices yet. Paired devices will appear here for fast 1-tap sync.',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: devices.map((device) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedSmartPhone01,
                              size: 22,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    device.deviceName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    device.autoSyncEnabled
                                        ? 'Auto-sync enabled'
                                        : 'Auto-sync disabled',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: device.autoSyncEnabled,
                              onChanged: (val) async {
                                final repo = TrustedDeviceRepository(
                                    ref.read(databaseProvider));
                                await repo.setAutoSyncEnabled(
                                    device.peerId, val);
                                ref.invalidate(trustedDevicesProvider);
                              },
                            ),
                            IconButton(
                              icon: HugeIcon(
                                icon: HugeIcons.strokeRoundedDelete02,
                                size: 20,
                                color: scheme.error,
                              ),
                              tooltip: 'Untrust device',
                              onPressed: () =>
                                  _confirmUntrust(context, ref, device),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmUntrust(
      BuildContext context, WidgetRef ref, TrustedDevice device) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Untrust Device'),
          content: Text(
            'Untrust "${device.deviceName}"? You will need to enter a pairing code next time it connects.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final repo =
                    TrustedDeviceRepository(ref.read(databaseProvider));
                await repo.untrustDevice(device.peerId);
                ref.invalidate(trustedDevicesProvider);
              },
              child: Text(
                'Untrust',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlassModeCard extends StatefulWidget {
  const _GlassModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_GlassModeCard> createState() => _GlassModeCardState();
}

class _GlassModeCardState extends State<_GlassModeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: widget.title,
      hint: widget.subtitle,
      button: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                          icon: widget.icon, size: 32, color: scheme.primary),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
