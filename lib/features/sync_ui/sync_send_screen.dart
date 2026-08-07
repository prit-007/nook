import 'package:flutter/material.dart';

/// Sync send screen — note selection + device discovery.
/// Full implementation in Phase 5.
class SyncSendScreen extends StatelessWidget {
  const SyncSendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notes'),
      ),
      body: const Center(
        child: Text('Sync Send (Phase 5)'),
      ),
    );
  }
}
