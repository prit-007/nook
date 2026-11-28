# Nook 1.0 Release Checklist

1. **Code Generation & Patches**
   - `flutter pub get`
   - `dart run build_runner build --delete-conflicting-outputs`
   - `dart run tool/patch_appflowy_editor.dart`
   - `dart run tool/patch_talker_flutter.dart`
   - `dart run tool/patch_sqlite3_android_log.dart`

2. **Quality & FOSS Gates**
   - `dart format --output=none --set-exit-if-changed .`
   - `dart run tool/licence_audit.dart`
   - `flutter analyze` (0 issues)
   - `flutter test -x network -x golden`
   - `flutter test --tags golden`

3. **Backup & Restore Drill**
   - `flutter test test/features/settings/backup_roundtrip_test.dart`
   - Verify lossless roundtrip across notes, checklists, notebooks, tags, attachments, reminders, templates, revisions, and note links.

4. **SBOM & Checksums**
   - `dart run tool/generate_sbom.dart` -> `build/sbom.json`
   - Verify SHA-256 checksums for all release APKs/installers.

5. **F-Droid Reproducible Build**
   - Split-per-ABI APKs (`armeabi-v7a`, `arm64-v8a`, `x86_64`) with `base * 10 + offset` version codes.
   - Verify `RAND_bytes` is defined in `libsqlite3.so` for every APK.
