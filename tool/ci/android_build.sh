#!/usr/bin/env bash
# Shared Android APK build for GitHub CI and the F-Droid metadata.
#
# Order of operations is identical on both build systems (reproducible-build
# requirement — do not reorder without validating sha256 parity against the
# published release APKs):
#   1. SQLCipher amalgamation (sqlite3.c)
#   2. static OpenSSL 3.x libcrypto for every Android ABI
#   3. app patches (tool/patch_*.dart)
#   4. release signing, but only when keystore secrets are present (CI);
#      F-Droid builds unsigned and signs with its own key
#   5. flutter build apk with SOURCE_DATE_EPOCH=0
#
# Usage: tool/ci/android_build.sh <sqlcipher-dir> [flutter-target-platform ...]
#   <sqlcipher-dir>  Existing checkout (F-Droid srclib, passed as $$sqlcipher$$)
#                    or a path to clone SQLCipher v4.5.7 into (CI: /opt/sqlcipher).
#   [platform ...]   e.g. android-arm android-arm64 android-x64 — one flutter
#                    build per platform. Omit for CI's full set (one build per
#                    platform plus one combined --split-per-abi build).
#
# Callers guarantee cwd is the repository root and flutter/dart are on PATH.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

SQLCIPHER_DIR=${1:?usage: android_build.sh <sqlcipher-dir> [platform ...]}
shift
PLATFORMS=("$@")

SQLCIPHER_TAG=v4.5.7
OPENSSL_DIR=${NOOK_OPENSSL_DIR:-/opt/openssl-android}
OPENSSL_VERSION=3.4.1
NDK=${ANDROID_HOME:-/opt/android-sdk}/ndk/28.2.13676358
TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64

# --- 1. SQLCipher amalgamation ---------------------------------------------
if [ ! -d "$SQLCIPHER_DIR" ]; then
  git clone --depth 1 --branch "$SQLCIPHER_TAG" \
    https://github.com/sqlcipher/sqlcipher.git "$SQLCIPHER_DIR"
fi
(
  cd "$SQLCIPHER_DIR"
  ./configure --enable-tempstore=yes --with-crypto-lib=none
  make sqlite3.c
)

# --- 2. static OpenSSL libcrypto per ABI ------------------------------------
# OpenSSL 3.4's android targets resolve the NDK by finding *clang on $PATH*
# inside $ANDROID_NDK_ROOT (Configurations/15-android.conf android_ndk());
# without it they die with "no NDK ...-gcc on $PATH". The toolchain PATH is
# scoped to this step only so it never leaks into the flutter/gradle build.
test -f "$NDK/source.properties"
test -x "$TOOLCHAIN/bin/aarch64-linux-android21-clang"
curl -fsSL "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz" \
  -o /tmp/openssl.tar.gz

build_openssl() {
  local TARGET=$1 DEST=$OPENSSL_DIR/$1 LOG=/tmp/openssl-$1.log
  rm -rf "/opt/openssl-$OPENSSL_VERSION" "$DEST"
  tar xzf /tmp/openssl.tar.gz -C /opt
  (
    export ANDROID_NDK_ROOT=$NDK
    export PATH="$TOOLCHAIN/bin:$PATH"
    # Reproducibility: mkbuildinf.pl embeds gmtime(SOURCE_DATE_EPOCH // time())
    # as "built on:", and Configure's Perl hashes decide configdata.pm/Makefile
    # ordering (archive-member/.text order). Pin both so libcrypto.a — and the
    # libsqlite3.so it links into — is byte-identical on every run.
    export SOURCE_DATE_EPOCH=0
    export PERL_HASH_SEED=0
    export PERL_PERTURB_KEYS=0
    cd "/opt/openssl-$OPENSSL_VERSION"
    ./Configure "$TARGET" -D__ANDROID_API__=21 no-shared no-tests no-ui-console
    # Compile output is huge (~4 MB per ABI) and CI jobs have log-size caps;
    # keep it in a file and only surface it when the build actually fails.
    if ! make build_libs -j"$(nproc)" >"$LOG" 2>&1; then
      tail -n 200 "$LOG"
      exit 1
    fi
  )
  mkdir -p "$DEST/lib" "$DEST/include"
  cp "/opt/openssl-$OPENSSL_VERSION/libcrypto.a" "$DEST/lib/"
  cp -r "/opt/openssl-$OPENSSL_VERSION/include/openssl" "$DEST/include/"
  test -f "$DEST/lib/libcrypto.a"
  test -f "$DEST/include/openssl/rand.h"
  echo "Built $TARGET -> $DEST/lib/libcrypto.a"
}

build_openssl android-arm64
build_openssl android-arm
build_openssl android-x86_64

# --- 3. app patches ---------------------------------------------------------
# patch_fdroid_sqlite rewrites pubspec to compile SQLCipher from source and
# links the per-ABI libcrypto.a above into the sqlite3 build hook.
dart run tool/patch_fdroid_sqlite.dart "$SQLCIPHER_DIR" "$OPENSSL_DIR"
dart run tool/patch_appflowy_editor.dart
dart run tool/patch_talker_flutter.dart
dart run tool/patch_mdns_dart.dart
dart run tool/patch_sqlite3_android_log.dart

# --- 4. release signing (only when CI secrets are present) ------------------
if [ -n "${KEYSTORE_BASE64:-}" ]; then
  echo "$KEYSTORE_BASE64" | base64 -d > android/app/upload-keystore.jks
  {
    echo "storeFile=upload-keystore.jks"
    echo "storePassword=${KEYSTORE_PASSWORD:?}"
    echo "keyAlias=${KEY_ALIAS:?}"
    echo "keyPassword=${KEY_PASSWORD:?}"
  } > android/key.properties
fi

# --- 5. reproducible flutter build -----------------------------------------
export SOURCE_DATE_EPOCH=0
if [ "${#PLATFORMS[@]}" -gt 0 ]; then
  for platform in "${PLATFORMS[@]}"; do
    flutter build apk --release --split-per-abi --target-platform="$platform" \
      --obfuscate --split-debug-info=build/symbols
  done
else
  flutter build apk --release --split-per-abi --target-platform=android-arm \
    --obfuscate --split-debug-info=build/symbols
  flutter build apk --release --split-per-abi --target-platform=android-arm64 \
    --obfuscate --split-debug-info=build/symbols
  flutter build apk --release --split-per-abi --target-platform=android-x64 \
    --obfuscate --split-debug-info=build/symbols
  flutter build apk --release --obfuscate --split-debug-info=build/symbols
fi
