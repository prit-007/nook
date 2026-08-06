import 'package:flutter/material.dart';

/// Notebook detail — filtered notes grid.
/// Full implementation in Phase 1.
class NotebookDetailScreen extends StatelessWidget {
  const NotebookDetailScreen({super.key, required this.notebookId});

  final String notebookId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notebook $notebookId'),
      ),
      body: const Center(
        child: Text('Notebook Detail (Phase 1)'),
      ),
    );
  }
}
