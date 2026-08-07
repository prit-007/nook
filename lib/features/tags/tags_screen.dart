import 'package:flutter/material.dart';

/// Tags list screen.
/// Full implementation in Phase 1.
class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: const Center(
        child: Text('Tags (Phase 1)'),
      ),
    );
  }
}
