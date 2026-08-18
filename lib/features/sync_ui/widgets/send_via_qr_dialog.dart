import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../sync/sync_orchestrator.dart';
import 'incoming_pairing_card.dart';
import 'qr_display_card.dart';

/// Desktop "send to mobile" flow. The desktop shows its QR code; the mobile
/// scans it, dials the desktop, and approves pairing — then the desktop pushes
/// the selected notes back to the mobile.
///
/// Opens [noteIds] to transfer once the mobile has paired. Returns true when a
/// transfer was actually sent, false if the user backed out or nothing paired.
Future<bool> showSendViaQrDialog(
  BuildContext context, {
  required List<String> noteIds,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SendViaQrDialog(noteIds: noteIds),
  ).then((result) => result ?? false);
}

class _SendViaQrDialog extends ConsumerStatefulWidget {
  const _SendViaQrDialog({required this.noteIds});

  final List<String> noteIds;

  @override
  ConsumerState<_SendViaQrDialog> createState() => _SendViaQrDialogState();
}

class _SendViaQrDialogState extends ConsumerState<_SendViaQrDialog> {
  List<String> _ownAddresses = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final notifier = ref.read(syncOrchestratorProvider.notifier);
    await notifier.startAdvertising();
    if (!mounted) return;
    setState(() {
      _ownAddresses = notifier.localMultiaddresses;
    });
  }

  Future<void> _confirmed() async {
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final syncState = ref.watch(syncOrchestratorProvider);
    final primaryAddress = _ownAddresses.isNotEmpty ? _ownAddresses.first : '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(syncOrchestratorProvider.notifier).stop();
      },
      child: AlertDialog(
        title: const Text('Send to phone'),
        content: SizedBox(
          width: 340,
          height: 460,
          child: syncState.pendingPairing != null
              ? SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedSmartPhone01,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'A phone found your code — approve the '
                              'pairing, then it will receive the notes.',
                              style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      IncomingPairingCard(onAccept: _confirmed),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () {
                          Navigator.of(context).pop(false);
                          ref.read(syncOrchestratorProvider.notifier).stop();
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ask the phone to open "Receive notes" and scan this '
                      'code.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (primaryAddress.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      )
                    else
                      QrDisplayCard(
                        data: primaryAddress,
                        title: 'Scan to receive',
                        caption: 'Show this QR code to the phone.',
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        ref.read(syncOrchestratorProvider.notifier).stop();
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
        ),
        actions: const [],
      ),
    );
  }
}
