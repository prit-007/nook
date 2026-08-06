import 'package:flutter/material.dart';

class SettingsSyncDevicesScreen extends StatelessWidget {
  const SettingsSyncDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sync Devices')),
      body: const Center(child: Text('Paired Devices (Phase 5)')),
    );
  }
}
