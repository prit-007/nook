import 'package:flutter/material.dart';

/// Locked notes — separate biometric re-prompt.
/// Full implementation in Phase 4.
class LockedNotesScreen extends StatelessWidget {
  const LockedNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Locked Notes'),
      ),
      body: const Center(
        child: Text('Locked Notes (Phase 4)'),
      ),
    );
  }
}
