import 'package:flutter/material.dart';

class SettingsStorageScreen extends StatelessWidget {
  const SettingsStorageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Backup')),
      body: const Center(child: Text('Storage Settings (Phase 6)')),
    );
  }
}
