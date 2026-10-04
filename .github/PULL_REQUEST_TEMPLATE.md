## What & why

<!-- Problem this PR solves; link the issue with Closes #N -->

## How validated

<!-- Commands run and what they proved -->

- [ ] `flutter pub get`
- [ ] `dart run build_runner build --delete-conflicting-outputs` (if codegen)
- [ ] `dart format --output=none --set-exit-if-changed .`
- [ ] `flutter analyze`
- [ ] `flutter test -x network`
- [ ] New/changed behavior covered by tests first (TDD)

## Test plan

<!-- Red tests added; what they cover -->

## Docs / changelog

- [ ] CHANGELOG.md `[Unreleased]` updated
- [ ] AGENTS.md / IMPLEMENTATION-CHECKLIST updated if behavior changed
- [ ] Migration bump documented if schemaVersion changed

## Risk notes

Migration, platform permissions, lockout, sync protocol compatibility.
