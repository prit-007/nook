# Linux Distribution Guide (Flatpak & AppImage)

Nook supports Linux desktop (`build-linux` CI job produces `nook-linux-x64.tar.gz`).

## Prerequisites
- `ninja-build`
- `libgtk-3-dev`
- `libsecret-1-dev` (required by `flutter_secure_storage_linux`)

## Building the Release Bundle
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build linux --release
```
Output: `build/linux/x64/release/bundle/`.

## Flatpak
A Flatpak manifest is provided at `linux/packaging/com.devparadise.nook.yml`:
```bash
flatpak-builder --force-clean build-dir linux/packaging/com.devparadise.nook.yml
```
Note: `--talk-name=org.freedesktop.secrets` is required for `libsecret` keystore access, and `--share=network` is used solely for local-network P2P Peer Sync.

## AppImage
To package `build/linux/x64/release/bundle/` as an AppImage, copy the bundle into `AppDir/usr/bin/`, link `AppRun` to `nook`, copy `linux/runner/icon.png` as the `.DirIcon`, and run `appimagetool AppDir/`.
