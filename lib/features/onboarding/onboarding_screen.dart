import 'package:flutter/material.dart';

/// Onboarding screen — first launch, pick vibe.
/// Full implementation in Phase 3.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.note_alt_outlined, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Your notes. Your device. Yours.',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('No account. No cloud. No one else reads your notes.'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushReplacementNamed('/home'),
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}
