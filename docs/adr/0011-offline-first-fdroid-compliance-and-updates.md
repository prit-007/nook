# 11. Offline-First Architecture & F-Droid Compliance

Date: 2026-11-01

## Status
Accepted

## Context
During initial F-Droid packaging and testing on Android 14 (ColorOS 14), reviewers noted:
1. On first launch during onboarding, the app contacted `api.github.com` via `update_checker.dart`.
2. The Android manifest requested `REQUEST_INSTALL_PACKAGES` to install downloaded APK updates.
3. F-Droid takes care of package updates and repository signatures; self-updating APKs are disallowed or flagged with Anti-Features (`UpstreamNonFree` / `Tracking`).
4. APK signatures from F-Droid (signed by F-Droid keys) and GitHub releases (signed by developer keys) conflict, so in-app APK installation fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.

## Decision
1. **Strict Offline-First Startup**:
   - Decouple all automated release checks from app lifecycle (`AppLifecycleState.resumed`) and startup.
   - Nook makes zero outbound network requests on cold start, during onboarding, or when resuming the app.
   - Remove the `UpdateBanner` from Home and the "Check for Updates" tile from Settings.
   - Keep the update subsystem codebase in `lib/features/updates/` dormant for future opt-in platform tooling, but completely remove it from active app runtime paths.
2. **Drop `REQUEST_INSTALL_PACKAGES`**:
   - Remove `android.permission.REQUEST_INSTALL_PACKAGES` from `android/app/src/main/AndroidManifest.xml`.
   - Nook relies on external package managers (F-Droid, GitHub Releases page, platform app stores) for updates.
3. **Distribution Guidance**:
   - Android releases on F-Droid use F-Droid's built-in update mechanism.
   - Users who obtain standalone APKs or desktop installers can check releases passively via the external browser link on the About screen (`SettingsAboutScreen`).

## Consequences
- Zero anti-features flagged by F-Droid scanners.
- Clean offline-first guarantee: the app only uses network sockets when the user explicitly initiates Peer Sync.
- Reduced attack surface with high-privilege Android package installer permissions removed.
