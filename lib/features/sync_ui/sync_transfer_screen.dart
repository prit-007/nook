import 'package:flutter/material.dart';

/// Sync transfer progress screen.
/// Full implementation in Phase 5.
class SyncTransferScreen extends StatelessWidget {
  const SyncTransferScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer'),
      ),
      body: Center(
        child: Text('Transfer $sessionId (Phase 5)'),
      ),
    );
  }
}
