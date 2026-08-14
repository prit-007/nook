# 8. Mobile editor toolbar + global keyboard shortcuts

Date: 2026-08-13

## Status
Accepted

## Context
Two desktop-vs-touch gaps surfaced once the editor was exercised on real mobile
hardware:

- **The `/` slash menu is desktop-only in `appflowy_editor 6.2.0`.** Its
  `_showSlashMenu` returns `false` immediately on mobile, so typing `/` silently
  does nothing. Removing that guard is not enough: the `SelectionMenu` overlay
  closes the soft keyboard and its navigation relies on hardware-keyboard
  events, which makes it unusable on touch devices. Mobile also needs an
  equivalent "insert a block" affordance, including the app's custom Doodle
  block type.

- **Desktop lacked global shortcuts.** Nook's desktop/web shell has no keyboard
  navigation for search or note creation, and AppFlowy's `EditorStyle.mobile`
  is used for all platforms in the note screen — there was no desktop-friendly
  way to reach search/new-note from the keyboard.

## Decision

### Mobile: a toolbar replaces the slash menu
1. `tool/patch_appflowy_editor.dart` also patches `slash_command.dart` (in
   addition to the existing `TextInputClient.onFocusReceived` override). On
   mobile the handler now inserts the `/` character as a visual breadcrumb and
   consumes the event (`return true`) **without** showing the `SelectionMenu`.
2. The editor is wrapped in `MobileToolbarV2`
   (`lib/features/editor/note_editor_screen.dart`,
   `_buildMobileToolbarItems()`), themed to the note's scheme, with:
   - a custom blocks menu mirroring the desktop slash menu's block types
     (H1/H2/H3, bulleted/numbered lists, checkbox, quote),
   - a Doodle **action** item (not a block-type toggle) that opens the doodle
     canvas via `_insertDoodle()`,
   - `textDecorationMobileToolbarItemV2`.

   The Doodle item is an action because it opens a full-screen canvas rather
   than toggling a block type; it needs the state method, so the toolbar items
   are built inside the state's `build`.

### Desktop: global keyboard shortcuts
`lib/core/widgets/keyboard_shortcuts.dart` (`NookKeyboardShortcuts`) wraps the
`MaterialApp.router.builder` output and binds, via `CallbackShortcuts` + an
autofocused `Focus`:

- `/` and Ctrl/Cmd+K → open search (`/home/search`)
- Ctrl/Cmd+N → new note (`/note/new`)

A guard refuses to fire while a text input owns the primary focus: the focused
widget's ancestor chain contains an `EditableText` (Flutter `TextField`,
`SearchBar`, …), or the focus lives in a nested `FocusScope` (the AppFlowy
editor wraps itself in one). This keeps typing `/` inside the editor opening the
desktop slash menu and prevents Ctrl/Cmd+K/N from being hijacked mid-edit.

## Consequences
- Desktop keeps the full slash menu; mobile gets a touch-native toolbar instead
  of a dead `/` or a broken overlay.
- The patch script now has two idempotent patch targets; the pub-cache edits are
  picked up by deleting `build/` before `flutter test` (see AGENTS.md).
- The guard is covered by widget tests
  (`test/core/widgets/keyboard_shortcuts_test.dart`): fires when nothing is
  focused or a plain button is focused; suppressed while a `TextField` is
  focused.
- Once `appflowy_editor` publishes the slash fix and `onFocusReceived`
  (>= 6.2.1), the patch target can be removed; the `MobileToolbarV2` wrapping
  and the keyboard-shortcuts widget stay as app code.
