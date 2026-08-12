import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/tables/notes.dart';
import '../../sync/sync_orchestrator.dart';
import '../../sync/transport/sync_transport.dart';

/// Sync send screen — note selection + device discovery.
class SyncSendScreen extends ConsumerStatefulWidget {
  const SyncSendScreen({super.key});

  @override
  ConsumerState<SyncSendScreen> createState() => _SyncSendScreenState();
}

class _SyncSendScreenState extends ConsumerState<SyncSendScreen> {
  final Set<String> _selectedNoteIds = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Start discovery when screen opens (errors are non-fatal in tests)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(syncOrchestratorProvider.notifier).startDiscovery();
      }
    });
  }

  @override
  void dispose() {
    // Don't stop discovery here — let the orchestrator manage it
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = ref.watch(databaseProvider);
    final syncState = ref.watch(syncOrchestratorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Notes'),
        actions: [
          if (_selectedNoteIds.isNotEmpty)
            TextButton(
              onPressed: syncState.phase == SyncPhase.sending
                  ? null
                  : () => _showDevicePicker(context),
              child: Text('Send (${_selectedNoteIds.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Device discovery status
          if (syncState.devices.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: syncState.devices.length,
                itemBuilder: (context, index) {
                  final device = syncState.devices[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: Icon(
                        Icons.phone_android,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(device.deviceName),
                      onPressed: () => _connectAndSend(context, device),
                    ),
                  );
                },
              ),
            ),
          if (syncState.phase == SyncPhase.discovering)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Searching for nearby devices...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (syncState.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                syncState.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Note>>(
              future: (db.select(db.notes)
                    ..where((t) => t.deleted.equals(false))
                    ..orderBy([
                      (t) => OrderingTerm.desc(t.pinned),
                      (t) => OrderingTerm.desc(t.updatedAt),
                    ]))
                  .get()
                  .then((notes) {
                if (_searchQuery.isEmpty) return notes;
                final q = _searchQuery.toLowerCase();
                return notes
                    .where((n) =>
                        n.title.toLowerCase().contains(q) ||
                        (n.plainText?.toLowerCase().contains(q) == true))
                    .toList();
              }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notes = snapshot.data ?? [];

                if (notes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.note_add_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notes to sync',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    final isSelected = _selectedNoteIds.contains(note.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedNoteIds.add(note.id);
                          } else {
                            _selectedNoteIds.remove(note.id);
                          }
                        });
                      },
                      title: Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _noteTypeLabel(note.type),
                        style: theme.textTheme.bodySmall,
                      ),
                      secondary: Icon(_noteTypeIcon(note.type)),
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

  void _showDevicePicker(BuildContext context) {
    final syncState = ref.read(syncOrchestratorProvider);
    if (syncState.devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No devices found. Make sure the receiver is visible.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select a device',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...syncState.devices.map(
              (device) => ListTile(
                leading: const Icon(Icons.phone_android),
                title: Text(device.deviceName),
                onTap: () {
                  Navigator.pop(context);
                  _connectAndSend(context, device);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _connectAndSend(BuildContext context, SyncDevice device) async {
    final notifier = ref.read(syncOrchestratorProvider.notifier);
    await notifier.connectToDevice(device);
    await notifier.sendNotes(_selectedNoteIds.toList());

    if (context.mounted) {
      final syncState = ref.read(syncOrchestratorProvider);
      if (syncState.phase == SyncPhase.complete) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sent ${_selectedNoteIds.length} notes')),
        );
        Navigator.pop(context);
      }
    }
  }

  String _noteTypeLabel(NoteType type) {
    switch (type) {
      case NoteType.text:
        return 'Text note';
      case NoteType.checklist:
        return 'Checklist';
      case NoteType.doodle:
        return 'Doodle';
      case NoteType.mixed:
        return 'Mixed';
    }
  }

  IconData _noteTypeIcon(NoteType type) {
    switch (type) {
      case NoteType.text:
        return Icons.note;
      case NoteType.checklist:
        return Icons.checklist;
      case NoteType.doodle:
        return Icons.brush;
      case NoteType.mixed:
        return Icons.dynamic_feed;
    }
  }
}
