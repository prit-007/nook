import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/haptics/haptics.dart';
import '../../core/providers/pin_provider.dart';
import '../../core/theme/app_motion.dart';

/// Native-style PIN entry screen — borderless keypad with clean,
/// unbordered typography mimicking iOS and Android lock screens.
class PinEntryScreen extends ConsumerStatefulWidget {
  const PinEntryScreen({
    super.key,
    this.isSetup = false,
    this.shuffledKeypad = false,
  });

  final bool isSetup;
  final bool shuffledKeypad;

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen> {
  String _entered = '';
  String? _error;
  bool _confirming = false;
  String? _firstEntry;
  late final List<List<String>> _keypadLayout;

  int get _pinLength => 6;

  @override
  void initState() {
    super.initState();
    if (widget.shuffledKeypad) {
      final digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']
        ..shuffle();
      _keypadLayout = [
        [digits[0], digits[1], digits[2]],
        [digits[3], digits[4], digits[5]],
        [digits[6], digits[7], digits[8]],
        ['', digits[9], '⌫'],
      ];
    } else {
      _keypadLayout = const [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
        ['', '0', '⌫'],
      ];
    }
  }

  void _onKey(String digit) {
    final pinProv = ref.read(pinProvider);
    if (pinProv.isLockedOut) return;

    unawaited(AppHaptics.light());
    setState(() {
      _error = null;
      if (_entered.length < _pinLength) _entered += digit;
      if (_entered.length == _pinLength) _submit();
    });
  }

  void _onBackspace() {
    unawaited(AppHaptics.selection());
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
          unawaited(AppHaptics.success());
          if (mounted) Navigator.of(context).pop(true);
        } else {
          unawaited(AppHaptics.error());
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
        unawaited(AppHaptics.success());
        if (mounted) Navigator.of(context).pop(true);
      } else {
        unawaited(AppHaptics.error());
        setState(() {
          if (pinProv.isLockedOut) {
            _error =
                'Too many attempts. Locked for ${pinProv.remainingLockoutSeconds}s';
          } else {
            _error = 'Incorrect PIN';
          }
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: scheme.error,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          widget.isSetup && _confirming
                              ? 'Re-enter your PIN'
                              : 'Enter your nook. PIN',
                          style: TextStyle(
                              fontSize: 14, color: scheme.onSurfaceVariant),
                        ),
                      const SizedBox(height: 24),

                      // PIN Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pinLength, (i) {
                          final filled = i < _entered.length;
                          return AnimatedContainer(
                            duration: AppMotion.short3,
                            curve: AppMotion.emphasizedDecelerate,
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  filled ? scheme.primary : Colors.transparent,
                              border: Border.all(
                                color: filled
                                    ? scheme.primary
                                    : scheme.outlineVariant,
                                width: 1.5,
                              ),
                            ),
                          );
                        }),
                      ),

                      const Spacer(),

                      // WhatsApp/iOS Style Keypad (No borders)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Column(
                          children: [
                            for (final row in _keypadLayout)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: row.map((digit) {
                                    if (digit.isEmpty) {
                                      return const SizedBox(width: 72);
                                    }

                                    final isBackspace = digit == '⌫';
                                    return GestureDetector(
                                      onTap: isBackspace
                                          ? _onBackspace
                                          : () => _onKey(digit),
                                      behavior: HitTestBehavior.opaque,
                                      child: Container(
                                        width: 72,
                                        height: 64,
                                        alignment: Alignment.center,
                                        child: isBackspace
                                            ? HugeIcon(
                                                icon: HugeIcons
                                                    .strokeRoundedBackward01,
                                                color: scheme.onSurface,
                                                size: 28,
                                              )
                                            : Text(
                                                digit,
                                                style: TextStyle(
                                                  fontSize: 30,
                                                  fontWeight: FontWeight.w400,
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
