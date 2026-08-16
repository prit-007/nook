import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:math' show Random;
import 'dart:ui';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/platform/wifi_direct.dart';
import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/tables/notes.dart';
import '../../sync/sync_orchestrator.dart';
import '../../sync/transport/sync_transport.dart';

class SyncSendScreen extends ConsumerStatefulWidget {
  const SyncSendScreen({super.key});

  @override
  ConsumerState<SyncSendScreen> createState() => _SyncSendScreenState();
}

class _SyncSendScreenState extends ConsumerState<SyncSendScreen>
    with TickerProviderStateMixin {
  final Set<String> _selectedNoteIds = {};
  final bool _selectAll = true;
  final String _searchQuery = '';
  Future<List<Note>>? _notesFuture;

  late AnimationController _radarController;
  SyncOrchestrator? _notifier;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _notifier = ref.read(syncOrchestratorProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshNotes();
        _notifier?.startDiscovery();
      }
    });
  }

  void _refreshNotes() {
    final db = ref.read(databaseProvider);
    setState(() {
      _notesFuture = _fetchNotes(db);
    });
    // Select all notes by default when they load.
    _notesFuture?.then((notes) {
      if (_selectAll && mounted) {
        setState(() {
          _selectedNoteIds.addAll(notes.map((n) => n.id));
        });
      }
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    // Leaving the sender must stop discovery — the periodic mDNS queries keep
    // sockets alive and advertising would otherwise run forever.
    unawaited(_notifier?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final syncState = ref.watch(syncOrchestratorProvider);
    final hasDevices = syncState.devices.isNotEmpty;

    return Scaffold(
      backgroundColor: scheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Radar',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedLink01,
              color: scheme.onSurface,
            ),
            tooltip: 'Manual Connection',
            onPressed: () => _showManualAddressDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---------------------------------------------------------
          // TOP HALF: The ShareIt/AirDrop Spatial Radar
          // ---------------------------------------------------------
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final centerX = constraints.maxWidth / 2;
                final centerY = constraints.maxHeight / 2;
                // Orbit radius capped so orbs + labels stay inside the radar
                // area on short screens (the orbit shrinks when needed).
                final radius = math.min(
                  140.0,
                  (constraints.maxHeight / 2) - 52,
                );

                // Force the Stack to fill the radar area: in a Column with
                // default crossAxisAlignment the Expanded gives loose width, so
                // a Stack alone would shrink-wrap and orbs positioned against
                // maxWidth would land outside it.
                return SizedBox.expand(
                  child: Stack(
                    alignment: Alignment.center,
                    // Let floating orbs spill over the frosted payload sheet —
                    // the spatial, AirDrop-style overlap is intentional and orbs
                    // must stay tappable.
                    clipBehavior: Clip.none,
                    children: [
                      // Radar Ripples
                      ...List.generate(3, (index) {
                        return AnimatedBuilder(
                          animation: _radarController,
                          builder: (context, child) {
                            final delay = index * 0.33;
                            final value =
                                (_radarController.value + delay) % 1.0;
                            return Transform.scale(
                              scale: 1.0 + (value * 3.0),
                              child: Opacity(
                                opacity: 1.0 - value,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: scheme.primary.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),

                      // Central Device Avatar (You)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.surface,
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.2),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedSmartPhone01,
                                color: scheme.primary,
                                size: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hasDevices
                                ? 'Tap a device to send'
                                : 'Searching...',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (!hasDevices) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ensure the receiver has "Receive Notes" open.',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Discovered Peers orbiting the center
                      if (hasDevices)
                        ...syncState.devices.asMap().entries.map((entry) {
                          final index = entry.key;
                          final device = entry.value;
                          // Distribute devices in a semi-circle or radial
                          // pattern.
                          final angle = (math.pi / 4) + (index * math.pi / 4);

                          return Positioned(
                            left: centerX + (radius * math.cos(angle)) - 40,
                            top: centerY + (radius * math.sin(angle)) - 40,
                            child: _FloatingPeerOrb(
                              device: device,
                              onTap: () {
                                if (_selectedNoteIds.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Select at least one note below.',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                _connectAndSend(context, device);
                              },
                            ),
                          );
                        }),

                      // Discovery error, if any.
                      if (syncState.error != null)
                        Positioned(
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  scheme.errorContainer.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              syncState.error!,
                              style: TextStyle(
                                color: scheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ---------------------------------------------------------
          // BOTTOM HALF: The Payload (Note Selection)
          // ---------------------------------------------------------
          Expanded(
            flex: 6,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(36),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest.withValues(alpha: 0.8),
                    border: Border(
                      top: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  // A Material (even transparent) between the tiles and the
                  // translucent container stops the "ListTile background color
                  // or ink splashes may be invisible" debug assertion — the
                  // tiles paint their ink on this Material instead of being
                  // hidden behind the frosted DecoratedBox.
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        // Payload Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payload',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: scheme.onSurface,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_selectedNoteIds.length} Notes Ready',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Note List
                        Expanded(
                          child: FutureBuilder<List<Note>>(
                            future: _notesFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: scheme.primary,
                                  ),
                                );
                              }
                              final notes = snapshot.data ?? [];
                              if (notes.isEmpty) {
                                return Center(
                                  child: Text(
                                    'Vault is empty.',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 40),
                                itemCount: notes.length,
                                itemBuilder: (context, index) {
                                  final note = notes[index];
                                  final isSelected = _selectedNoteIds.contains(
                                    note.id,
                                  );

                                  return CheckboxListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 4,
                                    ),
                                    secondary: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: HugeIcon(
                                        icon: _noteTypeIcon(note.type),
                                        size: 20,
                                        color: scheme.primary,
                                      ),
                                    ),
                                    title: Text(
                                      note.title.isEmpty
                                          ? 'Untitled'
                                          : note.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _noteTypeLabel(note.type),
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                    value: isSelected,
                                    activeColor: scheme.primary,
                                    checkboxShape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    onChanged: (value) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (value == true) {
                                          _selectedNoteIds.add(note.id);
                                        } else {
                                          _selectedNoteIds.remove(note.id);
                                        }
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Note>> _fetchNotes(AppDatabase db) async {
    final notes = await (db.select(
      db.notes,
    )
          ..where((t) => t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
    if (_searchQuery.isEmpty) return notes;
    final q = _searchQuery.toLowerCase();
    return notes
        .where(
          (n) =>
              n.title.toLowerCase().contains(q) ||
              (n.plainText?.toLowerCase().contains(q) == true),
        )
        .toList();
  }

  Future<void> _connectAndSend(
    BuildContext context,
    SyncDevice device,
  ) async {
    unawaited(HapticFeedback.mediumImpact());
    final pairingCode = (Random.secure().nextInt(900000) + 100000).toString();

    final confirmed = await context.push<bool>(
      '/sync/pairing',
      extra: {
        'pairingCode': pairingCode,
        'deviceName': device.deviceName,
      },
    );
    if (confirmed != true) return;

    // Wi-Fi Direct devices sit on a separate P2P network (the Quick Share
    // mechanism) — join the receiver's group first so the UDX dial can reach
    // it, then dial the group owner's IP with the advertised UDX port.
    var dialDevice = device;
    if (device.transportType == 'wifi-direct' &&
        device.wifiDirectAddress != null) {
      final owner = await WifiDirect.joinGroup(device.wifiDirectAddress!);
      if (owner == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Couldn't join the receiver's Wi-Fi Direct group. "
                'Are both devices nearby with Wi-Fi on?',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final portMatch = RegExp(r'/udp/(\d+)/udx')
          .firstMatch(device.multiaddresses?.first ?? '');
      dialDevice = SyncDevice(
        deviceId: device.deviceId,
        deviceName: device.deviceName,
        isOnline: true,
        transportType: device.transportType,
        wifiDirectAddress: device.wifiDirectAddress,
        multiaddresses: [
          '/ip4/$owner/udp/${portMatch?.group(1) ?? ''}/udx',
        ],
      );
    }

    final notifier = ref.read(syncOrchestratorProvider.notifier);
    await notifier.connectToDevice(dialDevice, pairingCode: pairingCode);

    final syncState = ref.read(syncOrchestratorProvider);
    if (syncState.phase == SyncPhase.error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(syncState.error ?? 'Connection failed')),
        );
      }
      return;
    }

    if (context.mounted) {
      unawaited(context.push('/sync/transfer/local-send'));
    }
    await notifier.sendNotes(_selectedNoteIds.toList());
  }

  /// Lets the user paste the receiver's multiaddr (shown on its "Receive
  /// Notes" screen) to dial it directly, bypassing mDNS discovery — the
  /// reliable path when multicast is blocked (AP client isolation, Windows
  /// firewall, VPN/multi-NIC).
  Future<void> _showManualAddressDialog(BuildContext context) async {
    final controller = TextEditingController();
    final address = await showDialog<String>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Add device manually'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste the receiver\'s address shown on its "Receive Notes" '
                'screen. It ends with /p2p/<peer id>.',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  hintText: '/ip4/192.168.1.20/udp/52341/udx/'
                      'p2p/12D3KooW...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Connect'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (address == null || address.trim().isEmpty) return;
    final device = SyncDevice.fromManualAddress(address);
    if (device == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid address — it must end with /p2p/<peer id>.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (_selectedNoteIds.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select at least one note to send.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await _connectAndSend(context, device);
  }

  String _noteTypeLabel(NoteType type) => switch (type) {
        NoteType.text => 'Text',
        NoteType.checklist => 'Checklist',
        NoteType.doodle => 'Doodle',
        NoteType.mixed => 'Mixed',
      };

  List<List<dynamic>> _noteTypeIcon(NoteType type) => switch (type) {
        NoteType.text => HugeIcons.strokeRoundedText,
        NoteType.checklist => HugeIcons.strokeRoundedCheckmarkSquare01,
        NoteType.doodle => HugeIcons.strokeRoundedPen01,
        NoteType.mixed => HugeIcons.strokeRoundedLayers01,
      };
}

/// The spatial avatar for discovered devices.
class _FloatingPeerOrb extends StatelessWidget {
  const _FloatingPeerOrb({required this.device, required this.onTap});
  final SyncDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Send to ${device.deviceName}',
      hint: 'Connect and send notes to this device',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedLaptop,
                  color: scheme.onPrimaryContainer,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                device.deviceName,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
