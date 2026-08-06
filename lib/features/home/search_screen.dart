import 'package:flutter/material.dart';

/// Search screen — instant FTS search.
/// Full implementation in Phase 1.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: const Center(
        child: Text('Search (Phase 1)'),
      ),
    );
  }
}
