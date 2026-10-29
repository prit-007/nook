import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/biometric_provider.dart';

/// Wraps the application tree to detect user interaction and enforce inactivity auto-lock.
class InactivityDetector extends ConsumerStatefulWidget {
  const InactivityDetector({
    super.key,
    required this.child,
    this.checkInterval = const Duration(seconds: 10),
    this.nowProvider,
  });

  final Widget child;
  final Duration checkInterval;
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends ConsumerState<InactivityDetector> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.checkInterval, (_) {
      if (!mounted) return;
      final gate = ref.read(biometricGateProvider);
      gate.checkInactivity(now: widget.nowProvider?.call());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  void _onInteraction() {
    ref.read(biometricGateProvider).recordActivity();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onInteraction(),
      onPointerMove: (_) => _onInteraction(),
      onPointerHover: (_) => _onInteraction(),
      child: widget.child,
    );
  }
}
