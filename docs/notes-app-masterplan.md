# Project Plan — "Own Your Notes"
### A FOSS, local-first, Material You 3 note-taking app (Flutter, Android + Web, Play Store ready)

---

## 1. The Positioning (why this can actually win)

Every big note app forces a tradeoff you're refusing to accept:
- Google Keep / Apple Notes → beautiful, easy, but cloud-tied and closed.
- Obsidian → local-first but nerdy, not "enjoyable" for casual note-taking.
- Notesnook → open source, E2E encrypted, genuinely good — but it's markdown/text-first, not visual/artistic.
- AppFlowy → open source, local-first, gorgeous — but it's a Notion-clone workspace tool, heavy for quick notes.
- Saber → excellent FOSS handwriting/doodle app, but narrow (just drawing, not full notes).

Your gap: **nobody has combined** (a) Material You 3 dynamic, per-note theming, (b) genuinely artistic/emotional UX, (c) zero-cloud-by-default local storage, (d) device-to-device sync with no server, and (e) doodle + checklist + rich text + image-notes in one coherent, FOSS, Play-Store-grade app. That's a real, defensible niche. Call this "Google Keep's ease + Samsung Notes' craft + total data ownership."

---

## 2. Core Product Principles (keep these pinned above your desk)

1. **Local-first, not local-only-as-an-afterthought.** No account, no login screen, no "sign in to continue." App works fully offline forever.
2. **Sync is a feature you opt into, not infrastructure you depend on.** P2P over LAN/Wi-Fi Direct, never a cloud relay.
3. **Every note can look different, but the *app chrome* stays consistent.** Otherwise "artistic" becomes "chaotic."
4. **Delight in the small interactions** (opening a note, checking a to-do, the FAB) — this is where "enjoyment" actually lives, not in big features.
5. **Security is default-on but invisible until needed** — biometric lock, per-note lock, encrypted-at-rest DB.

---

## 3. Tech Stack (validated against 2026 ecosystem health, not just popularity)

| Layer | Choice | Why |
|---|---|---|
| Framework | **Flutter (stable channel)** | Your existing skill set; single codebase → Android + Web + later desktop |
| Local database | **Drift (SQLite ORM)** | Hive and Isar are both effectively abandoned by their maintainer now; Drift is the actively-maintained, type-safe, reactive, cross-platform (incl. web via WASM) default recommendation in the 2026 Flutter ecosystem. Relational schema also suits notebooks/tags/checklist-items much better than a NoSQL box. |
| Encryption at rest | **SQLCipher via `sqlcipher_flutter_libs` + Drift**, key sealed in platform keystore | So "local-first" also means "actually private," not just "not synced" |
| Theming | **`dynamic_color` (official Flutter Community package)** + `ColorScheme.fromSeed` (Material 3) | Pulls the Android 12+ system wallpaper palette; you then re-derive a *seed color per note* (from a chosen color, tag, or the dominant color of an attached image) on top of the M3 tonal palette system |
| Rich text editor | **`flutter_quill`** (most mature FOSS rich-text editor for Flutter, Delta-based, extensible) | Handles bold/italic/checklists/images/embeds; you skin its toolbar to match your design language |
| Doodle / drawing canvas | Build custom on `CustomPainter` + `Path`, or fork ideas from **Saber** (FOSS, GPL-3, Flutter) which already solved pressure/stylus input, infinite canvas, and image export | Don't reinvent stroke smoothing — study Saber's renderer |
| Note → image export | `RepaintBoundary` + `dart:ui` `toImage()` → save via `gal` or `image_gallery_saver_plus` | Native "snapshot this note" feature |
| Biometric lock | **`local_auth`** (official Flutter plugin) | Face/fingerprint gate on app open and/or per-note |
| Local device-to-device sync | **`nearby_service`** (actively maintained, wraps Android Wi-Fi Direct / Nearby Connections and Apple Multipeer Connectivity) for the transport layer, with your own sync protocol on top | This is the "Quick Share for notes" feature — see §6 |
| State management | **Riverpod** | Pairs cleanly with Drift's reactive streams |
| Navigation | **go_router** | Standard, FOSS, good deep-link support for widget/share-intent entry points |
| CI/CD & release | GitHub Actions → Play Store (Fastlane optional) | Needed for "rock solid" repeatable releases |
| License | **GPL-3.0 or AGPL-3.0** | Matches the ethos (Notesnook uses GPL-3.0, AppFlowy AGPL-3.0) and prevents someone forking it into a closed SaaS |

**On "industry-grade":** don't just wrap Quill and call it done — the delta between "functional FOSS project" and "app people love" is 100% in animation, empty-states, haptics, and consistency. Budget real time for this, not just backend plumbing.

---

## 4. Data Model (sketch)

```
Notebook (id, name, colorSeed, icon, sortOrder)
Note (id, notebookId, type[text|checklist|doodle|mixed], title, deltaContent,
      colorSeed, coverImagePath, pinned, locked, createdAt, updatedAt,
      deviceOriginId, syncVersion)
ChecklistItem (id, noteId, text, checked, sortOrder)
Attachment (id, noteId, type[image|doodleLayer], filePath, thumbnailPath)
Tag (id, name, colorSeed)
NoteTag (noteId, tagId)
SyncLog (id, deviceId, noteId, action, timestamp)  -- for conflict resolution
```

Keep `deviceOriginId` + `updatedAt` (Lamport-ish versioning) from day one — retrofitting sync-safe IDs later is painful.

---

## 5. Screen-by-Screen Plan

### 5.1 Onboarding (first launch only, skippable, 3 screens max)
1. **Welcome** — one strong illustration, tagline ("Your notes. Your device. Yours."), no signup.
2. **Permissions primer** — explain *why* you'll ask for biometric/storage/nearby-Wi-Fi permission before the OS prompt fires (dramatically reduces permission-denial rates).
3. **Pick your vibe** — let the user choose an initial seed color / dynamic-from-wallpaper toggle. This is your first "artistic" touchpoint.

### 5.2 Home / Notes Grid (the app's soul)
- Masonry/staggered grid (Pinterest-style, like Keep) toggle-able to list view.
- Each note card tinted with its own M3 tonal palette; cover image or doodle thumbnail bleeds into the card.
- Top: search bar (local FTS via Drift's full-text search virtual tables) + avatar-less profile icon (settings) + view toggle.
- FAB with **speed-dial**: Text note / Checklist / Doodle / Voice-to-text(optional later) / Scan-image-to-note.
- Bottom or side nav: Notebooks, Tags, Locked notes, Trash (soft-delete, 30-day purge).
- Pull-to-refresh not needed (no cloud) — replace with a subtle "synced X devices nearby" pill when sync is active.

### 5.3 Note Editor
- Edge-to-edge, chrome fades away as you type (immersive writing mode).
- Floating contextual toolbar (Quill-based) that only appears on text selection or focus — not a permanent bar eating screen space.
- Color/theme picker accessible via a small swatch in the app bar — changing it live-restyles the whole editor chrome (this is your "different theme per note" hook).
- Checklist notes: drag-to-reorder, swipe-to-check, strikethrough animation.
- Doodle notes: separate full-canvas mode, layer support, stylus pressure if available, background templates (grid/ruled/blank/dotted).
- Image notes: pinch-zoom, markup-over-image (annotate), OCR-ready hook for later.
- Bottom sheet: lock this note (biometric), pin, add to notebook, tags, "Save as image," "Send to nearby device."

### 5.4 Notebooks / Tags view
- Simple folder-card grid; tags shown as chips with their own tonal color.

### 5.5 Search
- Local FTS, instant-as-you-type, results grouped by note vs. checklist-item matches.

### 5.6 Nearby Sync Screen (your signature feature)
- "Send" mode: pick **one note / selected notes / all notes** → tap "Find nearby devices" → radar-style animation discovers peers over Wi-Fi Direct/Nearby → tap target device → transfer with progress + checksum confirmation.
- "Receive" mode: toggle "Discoverable," accept incoming transfer requests (explicit consent, never silent).
- **Merge behavior (important, spec this precisely):** incoming notes are inserted as *new* notes if the note ID doesn't exist locally; if it does exist, show a diff/conflict resolution UI ("Keep both," "Keep newest," "Keep mine") — never silently overwrite. This directly satisfies your requirement that old notes stay untouched and new ones just appear.
- Small persistent "Last synced with [device] at [time]" log, viewable in Settings.

### 5.7 Settings
- Appearance: dynamic color on/off, manual seed color, dark/light/system, font.
- Security: biometric lock (app-level + per-note), auto-lock timer, screenshot-blocking toggle.
- Storage: DB size, export all notes (zip of markdown/images — your "no lock-in" promise made real), import.
- Sync: device name, paired-device history, clear sync log.
- About/License: GPL/AGPL notice, GitHub link, credits for FOSS libs used (legally required for most of them, and good practice).

### 5.8 Empty states, lock screen, trash
Don't skip these — a biometric lock screen with a nice illustration and a soft blur-behind, and a trash view with "auto-deletes in N days" messaging, are cheap wins that read as "polished."

---

## 6. The Nearby Sync Feature — Concrete Design

This is your hardest engineering problem, so plan it deliberately:

1. **Transport:** `nearby_service` gives you Wi-Fi Direct/Nearby Connections on Android and Multipeer on iOS-if-you-go-there-later. Note its current limitation: Android↔iOS cross-platform pairing isn't supported by that package — for a first release targeting Play Store/Android this is fine; keep it in mind if you ever add iOS.
2. **Discovery UX:** always explicit, user-initiated on both ends (advertise + browse), never background-silent — this matters for Play Store review and for user trust (your whole pitch is "you're in control").
3. **Payload:** serialize selected note(s) + attachments as a signed, versioned JSON/CBOR bundle + binary blobs, sent over the established socket in chunks with a progress callback.
4. **Conflict resolution:** last-write-wins is the *simplest* to ship v1, but expose a merge/duplicate-detection UI as described above so users never lose data silently.
5. **Trust:** show a device name + a short numeric confirmation code on both screens (like Bluetooth pairing) before the first transfer between two devices, to prevent accidental sends to a stranger's phone in a crowded place.

---

## 7. Build Roadmap (phased, so you always have something demoable)

**Phase 0 — Foundation (1–2 weeks)**
Project scaffold, Drift schema, Riverpod setup, go_router skeleton, CI pipeline, design tokens (color seeds, type scale, spacing) as a first "design system" artifact — do this before any screen so your UI stays consistent.

**Phase 1 — Core notes (2–3 weeks)**
Home grid, create/edit/delete text note, Quill integration, notebooks, tags, local search. Ship this as your first internal build — it should already feel good to use.

**Phase 2 — Checklists + Doodles + Images (3–4 weeks)**
Checklist note type, doodle canvas, image attach, note→image export/share to gallery.

**Phase 3 — Theming & polish (1–2 weeks)**
Dynamic color integration, per-note theming, animations/transitions, empty states, dark mode pass.

**Phase 4 — Security (1–2 weeks)**
SQLCipher encryption at rest, biometric lock (app + per-note), auto-lock, screenshot blocking.

**Phase 5 — Nearby Sync (3–4 weeks, your riskiest phase — start prototyping transport early in parallel)**
Transport integration, pairing UX, send/receive flows, conflict resolution, sync log.

**Phase 6 — Hardening for Play Store (2 weeks)**
Accessibility pass (TalkBack, contrast), tablet/foldable layout, backup/export/import, crash reporting (self-hosted or FOSS, e.g. **Sentry self-hosted** or none at all if you want zero telemetry), privacy policy page (mandatory even for a no-cloud app), store listing assets, closed testing track.

**Phase 7 — Launch + iterate**
Closed → open testing → production. Post-launch: widget support, voice-to-text notes, note templates, Flutter Web build polish.

---

## 8. Play Store Readiness Checklist (don't skip these — they're where solo devs get rejected)

- Privacy policy URL, even though you store nothing remotely (declare exactly what local permissions do).
- Data safety form: declare "no data collected/shared" honestly — this is actually a *marketing asset* for you, screenshot it.
- Target API level current requirement, 64-bit compliance, App Bundle (.aab) not APK.
- Runtime permission rationale dialogs before system prompts (nearby Wi-Fi, biometric, storage).
- Crash-free rate monitoring before wide rollout — even a simple opt-in local crash log you can ask users to email you is fine for a privacy-first app.

---

## 9. Suggested Repo/Project Structure

```
notes_app/
  lib/
    core/            (theming, constants, extensions, design tokens)
    data/            (drift tables, daos, repositories)
    sync/            (nearby_service wrapper, protocol, conflict resolver)
    features/
      home/
      editor/
      doodle/
      notebooks/
      search/
      sync_ui/
      settings/
      security/
    app.dart
  test/
  docs/              (architecture decisions, this plan, screen specs)
```

Start an `docs/adr/` folder (Architecture Decision Records) — even 3-line notes like "chose Drift over Isar because Isar is unmaintained (2026)" will save you enormous time when you forget your own reasoning in month 6.

---

## 10. Immediate Next Steps

1. Set up the repo + CI + Drift schema (Phase 0) this week.
2. Build the design tokens/theme system *before* any real screen — this is what makes "Material You dynamic per-note theming" feel coherent instead of chaotic.
3. Prototype `nearby_service` transport in isolation (a throwaway "send hello world between two phones" app) early, in parallel with Phase 1 — it's your biggest unknown, so de-risk it now rather than in month 4.
4. Study **Saber**'s doodle canvas and **Notesnook**'s editor architecture on GitHub for concrete implementation patterns — no need to reinvent stroke rendering or Quill theming from scratch.

Good luck — this is a well-scoped, genuinely useful, genuinely FOSS idea. The hardest part won't be any single feature, it'll be resisting scope creep before Phase 1 ships. Get the plain note-taking loop feeling delightful first; everything else layers on top of that foundation.
