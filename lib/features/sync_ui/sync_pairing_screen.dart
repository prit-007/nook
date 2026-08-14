import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'widgets/pairing_code_field.dart';

class SyncPairingScreen extends StatefulWidget {
  const SyncPairingScreen({
    super.key,
    required this.pairingCode,
    required this.deviceName,
  });

  final String pairingCode;
  final String deviceName;

  @override
  State<SyncPairingScreen> createState() => _SyncPairingScreenState();
}

class _SyncPairingScreenState extends State<SyncPairingScreen> {
  bool _isCopied = false;

  void _copyCode() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.pairingCode));
    setState(() => _isCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedSecurityCheck,
                  size: 64,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Confirm Identity',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify this code on ${widget.deviceName} to establish a secure connection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Tactile Code Field
              PairingCodeField(
                code: widget.pairingCode,
                accentColor: _isCopied
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.3),
                onTap: _copyCode,
              ),

              const SizedBox(height: 12),
              Text(
                _isCopied ? 'Copied to clipboard' : 'Tap to copy',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),

              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
