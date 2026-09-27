#!/usr/bin/env bash
# F-Droid metadata `prebuild` helper (metadata-only).
#
# Checks out the srclib Flutter checkout at the exact revision pinned by this
# repository's own CI (so the F-Droid build always matches GitHub CI), then
# installs it at /opt/flutter (srclibs live on a filesystem the build cannot
# write to in place, and CI expects /opt/flutter).
#
# Usage: tool/ci/fdroid_flutter_setup.sh <flutter-srclib-dir>
# Must be run from the repository root (the metadata runs it before the repo
# is moved into the CI-style workspace path).
set -euo pipefail

FLUTTER_SRC=${1:?usage: fdroid_flutter_setup.sh <flutter-srclib-dir>}

flutterVersion=$(sed -n -E "s/.*flutter-version:\ '(.*)'/\1/p" .github/workflows/ci.yml | head -1)
if [ -z "$flutterVersion" ]; then
  echo "Could not read flutter-version from .github/workflows/ci.yml" >&2
  exit 1
fi

git -C "$FLUTTER_SRC" checkout -f "$flutterVersion"
rm -rf /opt/flutter
mv "$FLUTTER_SRC" /opt/flutter
