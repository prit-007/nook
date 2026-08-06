import 'package:flutter/material.dart';

/// Sync history screen — past transfers.
/// Full implementation in Phase 5.
class SyncHistoryScreen extends StatelessWidget {
  const SyncHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync History'),
      ),
      body: const Center(
        child: Text('Sync History (Phase 5)'),
      ),
    );
  }
}
