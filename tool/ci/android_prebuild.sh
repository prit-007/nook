#!/usr/bin/env bash
# Shared prebuild for GitHub CI and the F-Droid metadata: code generation and
# the JNI linker-flags patch. Both callers guarantee:
#   * cwd is the repository root,
#   * `flutter`/`dart` are on PATH,
#   * PUB_CACHE points at the workspace-local pub cache.
#
# Usage: tool/ci/android_prebuild.sh
set -euo pipefail

flutter config --no-analytics
flutter pub get --enforce-lockfile
dart run build_runner build --delete-conflicting-outputs

# Drop the 16 KB max-page-size linker flag from jni's CMake config so the
# final APK layout matches the F-Droid buildserver's expectations.
sed -i 's/-Wl,-z,max-page-size=16384/-Wl,-z,max-page-size=16384,--build-id=none/' \
  "$PUB_CACHE"/hosted/pub.dev/jni-*/src/CMakeLists.txt
