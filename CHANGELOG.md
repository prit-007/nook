# Changelog

All notable changes to Nook are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-08-12

Major reliability and correctness release: a deep bug sweep across the sync
protocol, data layer, editor, and UI.

### Sync
- Received bundles are now processed serially, so back-to-back frames can no
  longer interleave database writes or acknowledgments.
- Attachment restore is idempotent: stale rows are removed before overwrite,
  doodle layers upsert instead of colliding on primary keys, and image IDs are
  preserved — re-syncing a note no longer duplicates files or rows.
- Frame writes are atomic per socket; a maximum frame size guards against
  memory-exhaustion; protocol version is validated on receive.
- Soft-deleted notes are never resurrected by sync; `syncVersion` bumps no
  longer drift `updatedAt`; clock-skew no longer causes incorrect overwrites.
- Transport cleanup now cancels all subscriptions and closes the pairing
  controller; a second device is rejected mid-transfer.

### Data layer
- Production vault now opens the encrypted on-disk database instead of
  in-memory, so data survives app restarts.
- Foreign keys are enforced; note deletion cascades to tags, checklists,
  attachments, and full-text search; multi-statement operations are
  transactional.
- `updateNote` no longer silently clears `notebookId`; `updateContent` keeps
  sync timestamps intact; `toggleChecked` is atomic; FTS5 queries are
  sanitized.
- Doodle saves write the sidecar file before creating the attachment row.

### Editor & UI
- Doodle strokes are persisted before the canvas closes, preventing data loss.
- Safe hex color parsing everywhere (no more crashes on malformed seeds).
- Editor saves no longer race disposal and keep the in-editor note fresh.
- Vault import/export, privacy screen, and live vault stats shipped.

## [0.6.2] - 2026-08-12

UI/UX redesign of the sync and settings surfaces — Lucide iconography, polished
copy, and a fixed conflict card crash.

### Sync screen
- Layout replaced with "glass mode" cards; Send and Receive actions promoted as
  prominent tappable cards.
- "Send to Device" card and a Sync History action moved into the app bar.

### Send flow
- Send screen now has a search bar for filtering the note selection list.
- Empty state copy updated to "No notes found."

### Receive flow
- Discoverable toggle with updated "Make this device visible" copy.
- Switched to a `LucideIcons.smartphone` device-name icon.

### Pairing & Transfer
- Pairing screen rewired: "Confirm Identity" trusted copy, Confirm / Cancel
  actions.
- Transfer screen reworked into distinct states — "Establishing Link...",
  "Beaming Notes..." / "Receiving Notes...", "Transfer Complete",
  and "Transfer Failed" — with the idle-state Cancel button removed.

### Conflict resolution (`ConflictCard`)
- Redesigned as an editorial split view with a tinted local panel
  ("This device") and an incoming remote panel ("Incoming"), using
  "Keep this device / Keep incoming / Keep both" actions.
- Fixed a crash where `CrossAxisAlignment.stretch` inside a min-height column
  threw an infinite-height assertion when the card rendered in a scrollable.

### Settings
- Appearance, Security, Storage, and About screens refreshed with Lucide icons
  and consistent layout.

### Other
- Swapped Material Icons for `LucideIcons` across sync UI.
- Widget tests updated for the new labels and icon assertions.

## [0.6.1] - 2026-08-12

### Fixed
- Sync conflict resolution: "Keep both" / "Keep remote" correctly preserve the
  note id and resolve the conflict; pairing screen full wiring.
- Applied `dart format` repo-wide.

## [0.6.0] - 2026-08-11

Editor UX upgrades, shape assist, checklist polish, and the CI release pipeline.

- Note editor: 300px reachability buffer, zen mode, glass app bar with dynamic
  date format, floating formatting pill.
- Checklist editor: animated progress bar, swipe-to-check, floating glass input
  pill, reorderable list with keyboard-aware padding.
- Doodle: `shapeAssistEnabled` toggle, rectangle snap detection, v2 codec with
  `isPerfectShape` field, backward-compatible deserialization.
- Doodle toolbar: shape assist as a toggle (not a tool), `activeColor` param.
- Sync: bonsoir TCP transport (replaces `nearby_service`), `_ackCompleter`
  cleanup, receive/send screen wiring, history refresh after clear.
- CI: GitHub Actions release pipeline with `softprops/action-gh-release`,
  tag-triggered APK builds, and auto-generated release notes.

[Unreleased]: https://github.com/anomalyco/nook/compare/v0.6.2...HEAD
[0.6.2]: https://github.com/anomalyco/nook/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/anomalyco/nook/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/anomalyco/nook/releases/tag/v0.6.0