import 'dart:async' show unawaited;
import 'dart:math' show Random;

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

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
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedNoteIds = {};
  bool _selectAll = true;
  String _searchQuery = '';
  Future<List<Note>>? _notesFuture;

  late AnimationController _pulseController;
  SyncOrchestrator? _notifier;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
    _pulseController.dispose();
    // Leaving the sender must stop discovery — the periodic mDNS queries keep
    // sockets alive and advertising would otherwise run forever.
    unawaited(_notifier?.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final syncState = ref.watch(syncOrchestratorProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Select Notes',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Row(
              children: [
                _buildRadarIndicator(
                  scheme,
                  isSearching: syncState.phase == SyncPhase.discovering,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        syncState.phase == SyncPhase.discovering
                            ? 'Searching for devices...'
                            : 'Nearby Devices',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Ensure the receiver has "Receive Notes" open.',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (syncState.devices.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: syncState.devices.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final device = syncState.devices[index];
                  return _DeviceChip(
                    device: device,
                    onTap: () {
                      if (_selectedNoteIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Select at least one note to send.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      _connectAndSend(context, device);
                    },
                  );
                },
              ),
            ),
          if (syncState.error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                syncState.error!,
                style:
                    TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              child: Material(
                // Use a Material (not a ColoredBox) so the ListTiles below can
                // paint their ink ripples and selection highlight on an opaque
                // ancestor; a plain Container would hide them and trigger the
                // "ListTile background color or ink splashes may be invisible"
                // debug assertion.
                color: scheme.surfaceContainerLowest,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search your vault...',
                          prefixIcon: HugeIcon(
                            icon: HugeIcons.strokeRoundedSearch01,
                            color: scheme.primary,
                            size: 24,
                          ),
                          filled: true,
                          fillColor: scheme.surfaceContainerHigh.withValues(
                            alpha: 0.5,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _refreshNotes();
                        },
                      ),
                    ),
                    FutureBuilder<List<Note>>(
                      future: _notesFuture,
                      builder: (context, snapshot) {
                        final notes = snapshot.data ?? [];
                        if (notes.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          child: Row(
                            children: [
                              Checkbox(
                                value:
                                    _selectedNoteIds.length == notes.length &&
                                        notes.isNotEmpty,
                                tristate: true,
                                activeColor: scheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (value) {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    _selectAll = value ?? true;
                                    if (_selectAll) {
                                      _selectedNoteIds
                                          .addAll(notes.map((n) => n.id));
                                    } else {
                                      _selectedNoteIds.clear();
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Select All',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_selectedNoteIds.length} selected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
                                'No notes found.',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 120),
                            itemCount: notes.length,
                            itemBuilder: (context, index) {
                              final note = notes[index];
                              final isSelected = _selectedNoteIds.contains(
                                note.id,
                              );

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 4,
                                ),
                                leading: Container(
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
                                  note.title.isEmpty ? 'Untitled' : note.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
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
                                trailing: Checkbox(
                                  value: isSelected,
                                  activeColor: scheme.primary,
                                  shape: RoundedRectangleBorder(
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
                                ),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (isSelected) {
                                      _selectedNoteIds.remove(note.id);
                                    } else {
                                      _selectedNoteIds.add(note.id);
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
        ],
      ),
    );
  }

  Widget _buildRadarIndicator(
    ColorScheme scheme, {
    required bool isSearching,
  }) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primaryContainer,
            boxShadow: isSearching
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(
                        alpha: 0.4 * (1.0 - _pulseController.value),
                      ),
                      spreadRadius: 20 * _pulseController.value,
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedRadar01,
            color: scheme.onPrimaryContainer,
            size: 28,
          ),
        );
      },
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

    final notifier = ref.read(syncOrchestratorProvider.notifier);
    await notifier.connectToDevice(device, pairingCode: pairingCode);

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

class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.device, required this.onTap});
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedSmartPhone01,
                  color: scheme.primary,
                  size: 20),
              const SizedBox(width: 10),
              Text(
                device.deviceName,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
