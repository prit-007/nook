# 10. Windows installer (Inno Setup)

Date: 2026-08-14

## Status
Accepted

## Context
Nook's Windows distribution was a raw zip of the `flutter build windows
--release` output. For a "tier-one" feel the Windows build needs a real setup
wizard: a branded, modern installer with an uninstaller, Start Menu entry, an
opt-in desktop shortcut, and a per-user install that does not demand admin
rights. The tooling should live in the repo so CI can produce the installer on
every tag build.

The `innosetup` pub package was evaluated first:
- Its latest version is `0.1.3` (3 years stale, low adoption).
- It **cannot** express the required behavior: no `PrivilegesRequired=lowest`
  (it hardcodes `DefaultDirName={autopf}`, requiring admin), the
  `AppPublisher` field is broken (it emits `homeUrl.path`, e.g. `/nook`), and
  the desktop shortcut is created unconditionally instead of as an opt-in task.
- It shells out to `iscc` internally with no hook between ISS generation and
  compilation.

## Decision
Skip the wrapper package; generate the Inno Setup script ourselves.

### `tool/build_installer.dart` (pure `dart:io`, zero new deps)
Pipeline: `flutter build windows --release` → `dart run tool/build_installer.dart`.

- Reads the app version from `pubspec.yaml` (`0.7.8`, build metadata stripped)
  and derives `build/installers/nook_setup_<ver>.iss` + `.exe`.
- Emits a hand-written `[Setup]` block: stable hardcoded `AppId` (clean
  upgrades over prior versions), `PrivilegesRequired=lowest` with
  `DefaultDirName={localappdata}\nook` (**no admin**), `WizardStyle=modern`,
  LZMA2 solid compression, `ArchitecturesInstallIn64BitMode`, GPL
  `LicenseFile`, and the app icon (`windows/runner/resources/app_icon.ico`).
- `[Tasks]` desktopicon is **opt-in** (unchecked); `[Icons]` creates the Start
  Menu entry always and the desktop entry only when the task is ticked;
  `[Run]` offers launch-after-install.
- `[Files]` ships `nook.exe` plus the whole Release dir
  (`recursesubdirs createallsubdirs`) so `data/`, `flutter_windows.dll`, and
  plugin DLLs land under `{app}`.
- Flags: `--dry-run` writes the `.iss` without requiring a Windows build or
  `iscc` (used to validate generation on any host); `--iscc <path>` points at
  `ISCC.exe` when it is not on PATH.

### CI
`build-windows` in `.github/workflows/ci.yml` installs Inno Setup via
Chocolatey (`choco install innosetup`), runs the installer build with an
explicit `--iscc` path, uploads `nook_setup_*.exe` in the `nook-windows`
artifact, and tag releases attach it to the GitHub release alongside the zip
and APKs.

## Consequences
- One self-contained Dart script, no new dependencies, fully reviewable; the
  generated `.iss` is easy to inspect and hand-tune.
- Installer behavior matches the premium intent: no-elevation install to
  `%LOCALAPPDATA%`, uninstaller in Windows Settings, Start Menu folder, opt-in
  desktop shortcut.
- Windows-only execution: `flutter build windows` and `iscc` cannot run on
  Linux/macOS; the script exits with a clear "run the release build first"
  message when `nook.exe` is missing and prints install instructions when
  `iscc` is absent.
- `_homeUrl` is a placeholder in the script and must be set to the real
  repository URL before a release.
