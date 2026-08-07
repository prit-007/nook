import 'package:flutter/material.dart';

class SettingsSecurityScreen extends StatelessWidget {
  const SettingsSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: const Center(child: Text('Security Settings (Phase 4)')),
    );
  }
}
