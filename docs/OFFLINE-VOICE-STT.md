# Offline Speech-to-Text (STT) Evaluation — Phase 5.1

## Evaluated Options

| Package | Engine | Licence | Platform Coverage | Notes |
|---|---|---|---|---|
| `whisper_cpp_flutter_plus` | whisper.cpp | MIT | Android, iOS | On-device GGML inference; desktop requires separate wrapper |
| `whisper_wrapper` | whisper.cpp | MIT | Windows, Linux x64 | Desktop FFI wrapper; mobile not included |
| Vosk Flutter plugin | Vosk / Kaldi | Apache-2.0 | Android, iOS | Bundles native Android binaries; loads offline model zip from assets/user storage |

## Decision
- Keep `NOOK_FDROID=true` builds completely free of `RECORD_AUDIO` and system speech recognition.
- Provide `OfflineVoiceModelManager` (`lib/core/platform/voice_capture_service.dart`) so users can import an offline model file verified against a mandatory **SHA-256 checksum** before storage, with zero network calls.
- Pinning and vendoring a unified FFI whisper/Vosk runtime remains gated behind a future release once cross-platform binary reproducibility is verified.
