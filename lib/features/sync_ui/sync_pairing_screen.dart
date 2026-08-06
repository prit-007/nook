import 'package:flutter/material.dart';

/// Sync pairing confirmation — numeric code on both devices.
/// Full implementation in Phase 5.
class SyncPairingScreen extends StatelessWidget {
  const SyncPairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairing'),
      ),
      body: const Center(
        child: Text('Pairing Confirmation (Phase 5)'),
      ),
    );
  }
}
