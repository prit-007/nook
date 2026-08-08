import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/design_tokens.dart';

/// Biometric lock screen per prompt #10.
/// Soft gradient background, frosted illustration, fingerprint icon with pulse,
/// "Unlock to see your notes", "Use PIN instead".
class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final seedColor = NookColors.violet;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              seedColor.withValues(alpha: 0.3),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App name at top
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Text(
                  'nook',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.7),
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Frosted illustration circle
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface.withValues(alpha: 0.6),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Notebook icon behind the blur
                        Icon(
                          Icons.note_alt_outlined,
                          size: 80,
                          color: seedColor.withValues(alpha: 0.15),
                        ),
                        // Fingerprint icon
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: seedColor.withValues(alpha: 0.15),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.fingerprint,
                            size: 48,
                            color: seedColor,
                          ),
                        ),
                        // Pulse rings
                        ...List.generate(3, (i) {
                          return Container(
                            width: 96.0 + (i + 1) * 24,
                            height: 96.0 + (i + 1) * 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: seedColor.withValues(
                                  alpha: 0.1 - i * 0.03,
                                ),
                                width: 1.5,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Text
              Text(
                'Unlock to see your notes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Face ID or fingerprint required',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),

              const SizedBox(height: 24),

              // PIN fallback
              TextButton(
                onPressed: () {
                  // TODO: implement PIN entry
                },
                child: Text(
                  'Use PIN instead',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
