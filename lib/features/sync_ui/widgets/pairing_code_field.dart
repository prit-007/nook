import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

/// Read-only [PinCodeTextField] that renders a pairing code cell-by-cell.
///
/// Tapping fires [onTap] (used for tap-to-copy); long-press paste is disabled
/// because the displayed code must never be editable.
class PairingCodeField extends StatefulWidget {
  const PairingCodeField({
    super.key,
    required this.code,
    this.onTap,
    this.accentColor,
  });

  final String code;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  State<PairingCodeField> createState() => _PairingCodeFieldState();
}

class _PairingCodeFieldState extends State<PairingCodeField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.code);
  }

  @override
  void didUpdateWidget(PairingCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _controller.text = widget.code;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor =
        widget.accentColor ?? scheme.outlineVariant.withValues(alpha: 0.3);

    return PinCodeTextField(
      appContext: context,
      length: widget.code.length,
      controller: _controller,
      readOnly: true,
      enabled: true,
      showCursor: false,
      enablePinAutofill: false,
      autoDisposeControllers: false,
      autoDismissKeyboard: true,
      keyboardType: TextInputType.number,
      beforeTextPaste: (_) => false,
      onTap: widget.onTap,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      pinTheme: PinTheme.defaults(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(16),
        fieldHeight: 58,
        fieldWidth: 42,
        borderWidth: 1.5,
        activeBorderWidth: 1.5,
        selectedBorderWidth: 1.5,
        inactiveBorderWidth: 1.5,
        fieldOuterPadding: const EdgeInsets.symmetric(horizontal: 3),
        activeColor: borderColor,
        selectedColor: borderColor,
        inactiveColor: borderColor,
        activeFillColor: scheme.surfaceContainerHighest,
        selectedFillColor: scheme.surfaceContainerHighest,
        inactiveFillColor: scheme.surfaceContainerHighest,
      ),
      textStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: scheme.onSurface,
      ),
    );
  }
}
