import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/pin_provider.dart';

/// PIN entry screen — numeric keypad for PIN verification.
/// Used both as lock screen fallback and for PIN setup.
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({super.key, this.isSetup = false});

  /// When true, the screen is for setting a new PIN (two-step entry).
  final bool isSetup;

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  String _entered = '';
  String? _error;
  bool _confirming = false;
  String? _firstEntry;

  int get _pinLength => 6;

  void _onKey(String digit) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (_entered.length < _pinLength) {
        _entered += digit;
      }
      if (_entered.length == _pinLength) {
        _submit();
      }
    });
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_entered.isNotEmpty) {
      setState(() {
        _error = null;
        _entered = _entered.substring(0, _entered.length - 1);
      });
    }
  }

  Future<void> _submit() async {
    final pinProv = ref.read(pinProvider);

    if (widget.isSetup) {
      if (!_confirming) {
        // First entry — store and ask for confirmation.
        setState(() {
          _firstEntry = _entered;
          _confirming = true;
          _entered = '';
        });
      } else {
        // Confirmation — compare.
        if (_entered == _firstEntry) {
          await pinProv.setPin(_entered);
          if (mounted) Navigator.of(context).pop(true);
        } else {
          setState(() {
            _error = 'PINs do not match. Try again.';
            _confirming = false;
            _firstEntry = null;
            _entered = '';
          });
        }
      }
    } else {
      // Verification mode.
      final ok = await pinProv.verify(_entered);
      if (ok) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = 'Incorrect PIN';
          _entered = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.isSetup
        ? (_confirming ? 'Confirm PIN' : 'Set a 6-digit PIN')
        : 'Enter your PIN';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: 14),
              )
            else
              Text(
                widget.isSetup && _confirming
                    ? 'Re-enter your PIN to confirm'
                    : 'Enter PIN to unlock',
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 32),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _entered.length;
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.15),
                  ),
                );
              }),
            ),

            const Spacer(),

            // Numeric keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  for (final row in [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                    ['', '0', '⌫'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((digit) {
                          if (digit.isEmpty) return const SizedBox(width: 72);
                          if (digit == '⌫') {
                            return _KeyButton(
                              onTap: _onBackspace,
                              child: Icon(
                                Icons.backspace_outlined,
                                color: scheme.onSurface,
                              ),
                            );
                          }
                          return _KeyButton(
                            onTap: () => _onKey(digit),
                            child: Text(
                              digit,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.onTap, required this.child});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
