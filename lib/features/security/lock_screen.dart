import 'package:flutter/material.dart';

/// Biometric lock screen.
/// Full implementation in Phase 4.
class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 16),
            const Text('Unlock to see your notes'),
            const SizedBox(height: 8),
            const Text('Face ID or fingerprint required'),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {},
              child: const Text('Use PIN instead'),
            ),
          ],
        ),
      ),
    );
  }
}
