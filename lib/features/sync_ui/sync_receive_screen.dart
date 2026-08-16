import 'dart:async' show unawaited;
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../sync/sync_orchestrator.dart';
import '../../sync/transport/sync_transport.dart';
import 'widgets/incoming_pairing_card.dart';
import 'widgets/qr_display_card.dart';
import 'widgets/qr_scan_screen.dart';
import 'widgets/conflict_card.dart';

/// Sync receive screen — an immersive "Broadcasting" beacon + incoming requests.
class SyncReceiveScreen extends ConsumerStatefulWidget {
  const SyncReceiveScreen({super.key});

  @override
  ConsumerState<SyncReceiveScreen> createState() => _SyncReceiveScreenState();
}

class _SyncReceiveScreenState extends ConsumerState<SyncReceiveScreen>
    with SingleTickerProviderStateMixin {
  SyncOrchestrator? _notifier;
  bool _shouldStopOnDispose = false;
  List<String> _ownAddresses = const [];

  late AnimationController _broadcastController;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(syncOrchestratorProvider.notifier);
    _broadcastController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    if (_shouldStopOnDispose) {
      unawaited(_notifier?.stop());
    }
    _broadcastController.dispose();
    super.dispose();
  }

  Future<void> _toggleDiscoverable(bool value) async {
    unawaited(HapticFeedback.lightImpact());
    if (value) {
      unawaited(_broadcastController.repeat());
      await ref.read(syncOrchestratorProvider.notifier).startAdvertising();
      if (mounted) {
        setState(() {
          _ownAddresses =
              ref.read(syncOrchestratorProvider.notifier).localMultiaddresses;
        });
      }
    } else {
      _broadcastController.stop();
      _broadcastController.reset();
      await ref.read(syncOrchestratorProvider.notifier).stop();
    }
  }

  Future<void> _copyAddress(String address) async {
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Address copied — paste it into the sender.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showQrCodeDialog(BuildContext context) {
    // Use the first address (primary multiaddr with /p2p/<peer id> suffix).
    final primaryAddress = _ownAddresses.first;
    showDialog<void>(
      context: context,
      builder: (_) => QrDisplayCard(
        data: primaryAddress,
        caption: 'Show this QR code to the sender.',
      ),
    );
  }

  /// Mobile "receive from desktop" path: scans the desktop's QR (shown on its
  /// send screen), dials it, and waits for the desktop to push the notes.
  Future<void> _scanAndReceive(BuildContext context) async {
    if (!qrCameraSupported) return;
    unawaited(HapticFeedback.mediumImpact());

    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (scanned == null || scanned.trim().isEmpty) return;

    final device = SyncDevice.fromManualAddress(scanned);
    if (device == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('That QR code is not a valid Nook address.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Both devices verify the same 6-digit code before any data moves.
    final pairingCode = (Random().nextInt(900000) + 100000).toString();
    if (!context.mounted) return;
    final confirmed = await context.push<bool>(
      '/sync/pairing',
      extra: {
        'pairingCode': pairingCode,
        'deviceName': device.deviceName,
      },
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(syncOrchestratorProvider.notifier)
        .connectToDevice(device, pairingCode: pairingCode);
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

    // Ensure the pulse animation tracks the Riverpod phase if rebuilt.
    if (isDiscoverable && !_broadcastController.isAnimating) {
      _broadcastController.repeat();
    } else if (!isDiscoverable && _broadcastController.isAnimating) {
      _broadcastController.stop();
      _broadcastController.reset();
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ---------------------------------------------------------
            // THE BEACON
            // ---------------------------------------------------------
            Expanded(
              flex: 4,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _toggleDiscoverable(!isDiscoverable),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isDiscoverable)
                            AnimatedBuilder(
                              animation: _broadcastController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale:
                                      1.0 + (_broadcastController.value * 1.5),
                                  child: Opacity(
                                    opacity: 1.0 - _broadcastController.value,
                                    child: Container(
                                      width: 120,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: scheme.primary
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDiscoverable
                                  ? scheme.primary
                                  : scheme.surfaceContainerHighest,
                              boxShadow: isDiscoverable
                                  ? [
                                      BoxShadow(
                                        color: scheme.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 32,
                                        spreadRadius: 8,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: HugeIcon(
                              icon: isDiscoverable
                                  ? HugeIcons.strokeRoundedWifi01
                                  : HugeIcons.strokeRoundedWifiOff01,
                              color: isDiscoverable
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      isDiscoverable
                          ? 'Visible to nearby devices'
                          : 'Invisible',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDiscoverable
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isDiscoverable
                          ? 'Waiting for incoming transfers...'
                          : 'Tap the icon to start broadcasting.',
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ---------------------------------------------------------
            // INCOMING REQUESTS & LOGIC
            // ---------------------------------------------------------
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    if (syncState.pendingPairing != null) ...[
                      // Incoming request card.
                      const IncomingPairingCard(),
                      const SizedBox(height: 20),
                    ],
                    if (syncState.phase == SyncPhase.receiving) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            syncState.receivedCount > 0
                                ? 'Receiving — ${syncState.receivedCount} notes'
                                : 'Receiving notes...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                    if (syncState.phase == SyncPhase.resolving &&
                        syncState.conflicts.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Conflicts (${syncState.conflicts.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...syncState.conflicts.map(
                        (conflict) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ConflictCard(
                            noteTitle: conflict.incoming.noteFields['title']
                                    as String? ??
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
                      ),
                    ],
                    if (syncState.phase == SyncPhase.complete) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
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
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedAlertCircle,
                              size: 28,
                              color: scheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                syncState.error!,
                                style: TextStyle(color: scheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_ownAddresses.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Connect manually',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                // Camera platforms can dial a desktop that is
                                // showing its QR on the send screen.
                                if (qrCameraSupported)
                                  FilledButton.tonalIcon(
                                    onPressed: () => _scanAndReceive(context),
                                    icon: HugeIcon(
                                      icon: HugeIcons.strokeRoundedQrCodeScan,
                                      size: 18,
                                      color: scheme.primary,
                                    ),
                                    label: const Text('Scan QR'),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                // QR code button (all platforms support display)
                                FilledButton.tonalIcon(
                                  onPressed: () => _showQrCodeDialog(context),
                                  icon: HugeIcon(
                                    icon: HugeIcons.strokeRoundedQrCode,
                                    size: 18,
                                    color: scheme.primary,
                                  ),
                                  label: const Text('QR Code'),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Show the QR code to the sender, or tap an '
                              'address to copy it.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._ownAddresses.map(
                              (address) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: InkWell(
                                  onTap: () => _copyAddress(address),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Row(
                                    children: [
                                      HugeIcon(
                                        icon: HugeIcons.strokeRoundedCopy01,
                                        color: scheme.primary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          address,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontFamily: 'monospace',
                                            color: scheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
