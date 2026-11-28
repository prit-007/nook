# Pub-Cache Patch Inventory (Phase 1.6)

Nook currently carries 7 idempotent patch scripts under `tool/` (invoked in `.github/actions/flutter-prep` and `tool/ci/android_build.sh`):

| Script | Target Package | Reason | Removal Condition |
|---|---|---|---|
| `tool/patch_appflowy_editor.dart` | `appflowy_editor ^6.2.0` | Adds `TextInputClient.onFocusReceived` override required by Flutter 3.44+ and fixes mobile `/` slash input | Remove when `appflowy_editor >= 6.2.1` publishes both fixes |
| `tool/patch_talker_flutter.dart` | `talker_flutter` | Wraps `ListTile`s in `Material(type: MaterialType.transparency)` to silence framework warnings | Remove when upstream `talker_flutter` wraps its tiles |
| `tool/patch_mdns_dart.dart` | `mdns_dart` / `dart_libp2p` | Fixes mDNS socket binding/interface handling on Android | Remove when upstream `dart_libp2p` includes the fix |
| `tool/patch_local_auth_windows.dart` | `local_auth_windows 2.0.1` | Defines `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` for MSVC | Remove when `local_auth_windows` drops `<experimental/coroutine>` |
| `tool/patch_flutter_local_notifications_windows.dart` | `flutter_local_notifications_windows` | Same MSVC C2338 coroutine deprecation define | Remove when upstream drops `<experimental/coroutine>` |
| `tool/patch_sqlite3_android_log.dart` | `sqlite3` | Links Android `liblog` in source-build hook | Remove when upstream `sqlite3` links `log` by default |
| `tool/patch_fdroid_sqlite.dart` | `sqlite3` + `pubspec.yaml` | Rewrites `sqlite3` hook to compile SQLCipher from source against static OpenSSL `libcrypto.a` for F-Droid reproducibility | Required until `sqlite3` supports external static OpenSSL path via user_defines |
