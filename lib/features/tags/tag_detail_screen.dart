import 'package:flutter/material.dart';

/// Tag detail — filtered notes grid.
/// Full implementation in Phase 1.
class TagDetailScreen extends StatelessWidget {
  const TagDetailScreen({super.key, required this.tagId});

  final String tagId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tag $tagId'),
      ),
      body: const Center(
        child: Text('Tag Detail (Phase 1)'),
      ),
    );
  }
}
