import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/biometric_provider.dart';

class SettingsSecurityScreen extends ConsumerWidget {
  const SettingsSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final gate = ref.watch(biometricGateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SwitchListTile(
              title: const Text('Biometric lock'),
              subtitle:
                  const Text('Lock your vault with Face ID or fingerprint'),
              secondary: Icon(
                Icons.fingerprint,
                color: scheme.primary,
              ),
              value: gate.enabled,
              onChanged: (value) =>
                  ref.read(biometricGateProvider).setEnabled(value),
            ),
          ),
        ],
      ),
    );
  }
}
