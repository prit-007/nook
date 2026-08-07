import 'package:flutter/material.dart';

/// Notebooks list screen.
/// Full implementation in Phase 1.
class NotebooksScreen extends StatelessWidget {
  const NotebooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notebooks'),
      ),
      body: const Center(
        child: Text('Notebooks (Phase 1)'),
      ),
    );
  }
}
