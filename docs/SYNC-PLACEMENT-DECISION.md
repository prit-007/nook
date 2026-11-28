# Sync Placement Decision

**Status:** Accepted  
**Scope:** Navigation shell (`lib/core/widgets/app_shell.dart`), Home (`lib/features/home/home_screen.dart`), Settings (`lib/features/settings/settings_screen.dart`)

## Decision

Peer-to-peer Sync is surfaced as:
1. A **live status pill** in the Home hero header (`NookHeroSliver` -> `_SyncPill` in `lib/features/home/widgets/nook_hero.dart`) that displays the current sync state (`Synced`, `Syncing`, `Conflict`, `Local only`) and navigates directly to `/sync` on tap.
2. A **dedicated entry in Settings** (`Storage & Sync` section in `lib/features/settings/settings_screen.dart`: `Peer Sync` -> `/sync`, `Paired Devices` -> `/settings/sync-devices`, `Sync History` -> `/sync/history`).

Sync is **not** placed as a 5th tab in the mobile floating bottom dock (`_MobileShell` in `lib/core/widgets/app_shell.dart`).

## Rationale

1. **4-item bottom dock clarity:** `_MobileShell` uses a floating pill dock with four primary destinations: **Home**, **Notebooks**, **Tags**, and **Settings**. Keeping the dock at four items preserves comfortable touch targets, legible labels (`>= 12sp` floor), and visual breathing room on compact mobile screens (`< 600dp`).
2. **Infrequent explicit P2P action:** Nook is local-first with explicit LAN/Wi-Fi Direct peer-to-peer transfers (pairing codes, device discovery, conflict review) rather than continuous background cloud polling. Users spend the vast majority of sessions reading, writing, and organizing notes, only initiating sync when transferring between devices.
3. **High-visibility status without navigation bloat:** Placing the status pill in `HomeScreen` (`NookHeroSliver`) gives users immediate at-a-glance awareness of sync state (including actionable conflict badges) and one-tap access to `/sync`, while `SettingsScreen` provides a predictable home for sync configuration, paired devices, and transfer history.
