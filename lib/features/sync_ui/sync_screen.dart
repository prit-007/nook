import 'package:flutter/material.dart';

/// Sync screen — Send/Receive toggle.
/// Full implementation in Phase 5.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync'),
      ),
      body: const Center(
        child: Text('Nearby Sync (Phase 5)'),
      ),
    );
  }
}
