import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/platform/voice_capture_service.dart';
import '../../../core/providers/voice_preference_provider.dart';

/// Opens a modal bottom sheet for live voice-to-text dictation.
///
/// Before first use, shows a one-time disclosure explaining that voice uses
/// the device's speech service (and recommending offline providers like
/// Marmalade STT on Android). Returns `null` if the user declines or cancels.
Future<String?> showVoiceCaptureSheet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final voicePref = container.read(voicePreferenceProvider);
  if (!voicePref.disclosureAccepted) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Voice speech service'),
        content: const Text(
          "Voice uses your phone's speech service. It may send audio to "
          'that service, depending on your phone.\n\n'
          'For offline speech recognition on Android, you can install an '
          'offline speech provider such as Marmalade STT.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return null;
    await voicePref.acceptDisclosure();
  }

  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _VoiceCaptureSheet(),
  );
}

class _VoiceCaptureSheet extends ConsumerStatefulWidget {
  const _VoiceCaptureSheet();

  @override
  ConsumerState<_VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends ConsumerState<_VoiceCaptureSheet> {
  late final VoiceCaptureService _voiceService;
  String _transcript = '';
  String? _error;
  bool _initializing = true;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _voiceService = ref.read(voiceCaptureServiceProvider);
    unawaited(_start());
  }

  @override
  void dispose() {
    unawaited(_voiceService.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    final service = _voiceService;
    setState(() {
      _initializing = true;
      _error = null;
    });
    final available = await service.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
      onError: (err) {
        if (!mounted) return;
        final isPermissionError = err.toLowerCase().contains('permission') ||
            err.toLowerCase().contains('denied');
        setState(() {
          _listening = false;
          _error = isPermissionError
              ? 'Microphone permission is required for voice capture. Please grant access in device settings.'
              : err;
        });
      },
    );
    if (!mounted) return;
    if (!available) {
      setState(() {
        _initializing = false;
        _listening = false;
        _error = _error ??
            'Speech recognition is not available on this device.';
      });
      return;
    }

    setState(() {
      _initializing = false;
      _listening = true;
    });
    await service.startListening(
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _transcript = words;
          if (isFinal) _listening = false;
        });
      },
    );
  }

  Future<void> _finish() async {
    unawaited(HapticFeedback.selectionClick());
    await ref.read(voiceCaptureServiceProvider).stopListening();
    if (!mounted) return;
    final trimmed = _transcript.trim();
    Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _listening
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHigh,
            ),
            child: Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedMic01,
                size: 28,
                color: _listening ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _initializing
                ? 'Preparing microphone…'
                : (_listening ? 'Listening…' : 'Voice capture'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 88, maxHeight: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SingleChildScrollView(
              child: Text(
                _error ??
                    (_transcript.isEmpty
                        ? 'Speak naturally to dictate a note…'
                        : _transcript),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _error != null
                          ? scheme.error
                          : (_transcript.isEmpty
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              if (_error != null)
                Expanded(
                  child: FilledButton(
                    onPressed: _start,
                    child: const Text('Retry'),
                  ),
                )
              else
                Expanded(
                  child: FilledButton(
                    onPressed: _transcript.trim().isEmpty ? null : _finish,
                    child: const Text('Use Text'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
