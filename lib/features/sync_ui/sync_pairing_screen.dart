import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'widgets/pairing_code_field.dart';

/// The mutual-confirmation pairing screen shown on BOTH devices while a
/// transfer is being set up.
///
/// - Sender: shows the code it generated; the user taps **Confirm**, which
///   dials the receiver and keeps THIS screen visible in a "Waiting for
///   [deviceName]…" state. It only pops with `true` once the receiver has
///   also accepted the same code.
/// - When [onConfirm] is null (e.g. a standalone preview) tapping Confirm
///   pops immediately with `true`.
///
/// This guarantees both users see the same PIN at the same time and a
/// connection is only established after BOTH accept.
class SyncPairingScreen extends StatefulWidget {
  const SyncPairingScreen({
    super.key,
    required this.pairingCode,
    required this.deviceName,
    this.onConfirm,
  });

  final String pairingCode;
  final String deviceName;

  /// Optional callback that establishes the connection (e.g. dials the
  /// receiver). When provided, tapping Confirm runs it and the screen stays
  /// open until it resolves: `true` pops the screen with `true`, `false`
  /// keeps the screen open with an error so the user can retry or cancel.
  final Future<bool> Function()? onConfirm;

  @override
  State<SyncPairingScreen> createState() => _SyncPairingScreenState();
}

class _SyncPairingScreenState extends State<SyncPairingScreen> {
  bool _isCopied = false;
  bool _connecting = false;
  String? _error;

  void _copyCode() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.pairingCode));
    setState(() => _isCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  Future<void> _handleConfirm() async {
    final onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });
    final ok = await onConfirm();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _connecting = false;
        _error = 'Connection failed. The other device may have rejected the '
            'code or is out of reach.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
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
                _connecting
                    ? 'Waiting for ${widget.deviceName} to confirm the same '
                        'code…'
                    : 'Verify this code on ${widget.deviceName} to establish a '
                        'secure connection.',
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

              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedAlertCircle,
                        size: 20,
                        color: scheme.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),
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
                      onPressed: _connecting
                          ? null
                          : () => Navigator.of(context).pop(false),
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
                      onPressed: _connecting ? null : _handleConfirm,
                      child: _connecting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
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
