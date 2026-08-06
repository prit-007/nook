import 'package:flutter/material.dart';

/// Trash screen — soft-deleted notes.
/// Full implementation in Phase 1.
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
      ),
      body: const Center(
        child: Text('Trash (Phase 1)'),
      ),
    );
  }
}
