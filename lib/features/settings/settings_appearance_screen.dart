import 'package:flutter/material.dart';

class SettingsAppearanceScreen extends StatelessWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: const Center(child: Text('Appearance Settings (Phase 3)')),
    );
  }
}
