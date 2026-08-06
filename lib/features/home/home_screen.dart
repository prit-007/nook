import 'package:flutter/material.dart';

/// Home screen — notes grid with search bar, filter chips, FAB.
/// Full implementation in Phase 1.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nook'),
      ),
      body: const Center(
        child: Text('Home — Notes Grid (Phase 1)'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
