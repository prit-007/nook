import 'package:flutter/material.dart';

/// Sync receive screen — discoverable toggle + incoming requests.
/// Full implementation in Phase 5.
class SyncReceiveScreen extends StatelessWidget {
  const SyncReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Notes'),
      ),
      body: const Center(
        child: Text('Sync Receive (Phase 5)'),
      ),
    );
  }
}
