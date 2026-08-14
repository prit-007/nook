import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/pin_provider.dart';

/// Adaptive PIN entry screen — numeric keypad for PIN verification.
/// Uses `CustomScrollView` + `SliverFillRemaining` so the layout never
/// overflows on landscape or short screens.
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
    HapticFeedback.lightImpact();
    setState(() {
      _error = null;
      if (_entered.length < _pinLength) _entered += digit;
      if (_entered.length == _pinLength) _submit();
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
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
        setState(() {
          _firstEntry = _entered;
          _confirming = true;
          _entered = '';
        });
      } else {
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
      final ok = await pinProv.verify(_entered);
      if (ok) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        unawaited(HapticFeedback.heavyImpact());
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
        : 'Enter PIN';

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        widget.isSetup && _confirming
                            ? 'Re-enter your PIN to confirm'
                            : 'Secure vault access',
                        style: TextStyle(
                          fontSize: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),

                    const SizedBox(height: 48),

                    // PIN Dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pinLength, (i) {
                        final filled = i < _entered.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          width: filled ? 16 : 12,
                          height: filled ? 16 : 12,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                          ),
                        );
                      }),
                    ),

                    const Spacer(),

                    // Responsive Keypad
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Column(
                        children: [
                          for (final row in [
                            ['1', '2', '3'],
                            ['4', '5', '6'],
                            ['7', '8', '9'],
                            ['', '0', '⌫'],
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: row.map((digit) {
                                  if (digit.isEmpty) {
                                    return const SizedBox(width: 80);
                                  }

                                  final isBackspace = digit == '⌫';
                                  return _KeyButton(
                                    onTap: isBackspace
                                        ? _onBackspace
                                        : () => _onKey(digit),
                                    isBackspace: isBackspace,
                                    child: isBackspace
                                        ? Icon(
                                            Icons.backspace_outlined,
                                            color: scheme.onSurface,
                                            size: 28,
                                          )
                                        : Text(
                                            digit,
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w600,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.onTap,
    required this.child,
    required this.isBackspace,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool isBackspace;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isBackspace
                ? Colors.transparent
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
