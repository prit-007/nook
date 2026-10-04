import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/vault_password_provider.dart';

/// Prompts for the vault password when locked notes require it.
///
/// Returns true when unlocked (or vault disabled).
Future<bool> ensureVaultUnlocked(
  BuildContext context,
  WidgetRef ref, {
  String reason = 'This note is protected by your vault password',
}) async {
  final vault = ref.read(vaultPasswordProvider);
  if (!vault.enabled || vault.isUnlocked) return true;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => VaultPasswordDialog(reason: reason),
  );
  return ok == true;
}

/// Shows a dialog to set a new vault password.
Future<bool> showSetVaultPasswordDialog(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const VaultPasswordSetDialog(),
  );
  return ok == true;
}

class VaultPasswordDialog extends ConsumerStatefulWidget {
  const VaultPasswordDialog({
    super.key,
    this.reason = 'Enter your vault password to continue',
  });

  final String reason;

  @override
  ConsumerState<VaultPasswordDialog> createState() =>
      _VaultPasswordDialogState();
}

class _VaultPasswordDialogState extends ConsumerState<VaultPasswordDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    unawaited(HapticFeedback.lightImpact());
    final vault = ref.read(vaultPasswordProvider);
    final ok = await vault.unlock(_controller.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _checking = false;
        _error = 'Incorrect vault password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Vault locked'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.reason),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Vault password',
              errorText: _error,
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedLock,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _checking ? null : _submit,
          child: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Unlock'),
        ),
      ],
    );
  }
}

class VaultPasswordSetDialog extends ConsumerStatefulWidget {
  const VaultPasswordSetDialog({super.key});

  @override
  ConsumerState<VaultPasswordSetDialog> createState() =>
      _VaultPasswordSetDialogState();
}

class _VaultPasswordSetDialogState
    extends ConsumerState<VaultPasswordSetDialog> {
  final _controller = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final password = _controller.text;
    final confirm = _confirmController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Password must not be empty');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    unawaited(HapticFeedback.lightImpact());
    try {
      await ref.read(vaultPasswordProvider).setPassword(password);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not set vault password';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Set vault password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'A second password for locked notes. Exported vaults are not '
            'password-wrapped — this gates the in-app session only.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Vault password',
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedLock,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              errorText: _error,
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedLock,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enable vault'),
        ),
      ],
    );
  }
}
