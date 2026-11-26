import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/security/dek_manager.dart';
import 'widgets/lock_illustration.dart';

/// Full-screen cold-start gate shown when SQLCipher DEK wrapping (C2) is
/// active so the encrypted database cannot be opened until the user unwraps
/// the DEK with their vault password or 24-word recovery key.
class VaultDbGateScreen extends StatefulWidget {
  const VaultDbGateScreen({
    super.key,
    required this.dekManager,
    required this.hasRecoveryKey,
    required this.onUnlocked,
  });

  final DekManager dekManager;
  final bool hasRecoveryKey;
  final Future<void> Function(String dek, String? password) onUnlocked;

  @override
  State<VaultDbGateScreen> createState() => _VaultDbGateScreenState();
}

class _VaultDbGateScreenState extends State<VaultDbGateScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _recoveryMode = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error = _recoveryMode
            ? 'Enter your 24-word recovery phrase'
            : 'Enter your vault password';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final dek = _recoveryMode
        ? await widget.dekManager.unwrapDekWithRecoveryKey(input)
        : await widget.dekManager.unwrapDekWithPassword(_controller.text);

    if (!mounted) return;
    if (dek == null) {
      setState(() {
        _submitting = false;
        _error = _recoveryMode
            ? 'Invalid recovery phrase'
            : 'Incorrect vault password';
      });
      return;
    }

    await widget.onUnlocked(dek, _recoveryMode ? null : _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LockIllustration(
                    primaryIcon: HugeIcons.strokeRoundedLock,
                    badgeIcon: HugeIcons.strokeRoundedKey01,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _recoveryMode
                        ? 'Recover Encrypted Vault'
                        : 'Unlock Your Vault',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _recoveryMode
                        ? 'Enter your 24-word recovery phrase to unwrap your database key.'
                        : 'Your database encryption key is protected by your vault password.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    obscureText: !_recoveryMode && _obscure,
                    maxLines: _recoveryMode ? 3 : 1,
                    enabled: !_submitting,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: _recoveryMode
                          ? '24-word recovery phrase'
                          : 'Vault password',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                      suffixIcon: _recoveryMode
                          ? null
                          : IconButton(
                              tooltip:
                                  _obscure ? 'Show password' : 'Hide password',
                              icon: HugeIcon(
                                icon: _obscure
                                    ? HugeIcons.strokeRoundedView
                                    : HugeIcons.strokeRoundedViewOff,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Unlock Vault'),
                    ),
                  ),
                  if (widget.hasRecoveryKey) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              setState(() {
                                _recoveryMode = !_recoveryMode;
                                _error = null;
                                _controller.clear();
                              });
                            },
                      child: Text(
                        _recoveryMode
                            ? 'Use vault password instead'
                            : 'Use 24-word recovery key',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
