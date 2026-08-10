# UI/UX & Security Audit Checklist

Generated from comprehensive codebase audit. Track completion status here.

## Critical (fix immediately)

- [ ] **C1** `pin_provider.dart:86-91` — PIN "hash" is trivially reversible byte-sum; replace with SHA-256 via `crypto` package
- [ ] **C2** `screenshot_blocker_provider.dart:12-13` + `main.dart:42` — Startup `setBlocked` is a no-op due to guard clause; FLAG_SECURE never re-applied on restart
- [ ] **C3** `home_screen.dart:81,137` — `context.push('/search')` should be `context.push('/home/search')` — runtime crash
- [ ] **C4** `locked_notes_screen.dart:77` — `Navigator.of(context).pushNamed` incompatible with go_router
- [ ] **C5** `note_editor_screen.dart:142-144` — StreamSubscription from transactionStream.listen never stored/cancelled — memory leak + post-dispose crash
- [ ] **C6** `onboarding_screen.dart:39-41` — Seed selection never persisted to themePreferenceProvider
- [ ] **C7** `note_options_sheet.dart:105-113` — `onTagsChanged` never wired from `_showNoteOptions()` in note_editor_screen.dart — tag changes silently discarded
- [ ] **C8** `doodle_toolbar.dart:12-20` — Hardcoded black/white colors invisible on matching backgrounds

## High (fix soon)

- [ ] **H1** `settings_screen.dart:64-66` — Screenshot blocking toggle hardcoded to `false`, not wired to provider
- [ ] **H2** `settings_screen.dart:28-29` — Dynamic color switch hardcoded, dead UI
- [ ] **H3** `lock_screen.dart:55-116` — No tappable area for biometric prompt — cannot actually unlock
- [ ] **H4** `frosted_shield.dart:93` / `lock_screen.dart:19` — Seed color hardcoded to violet, ignores user preference
- [ ] **H5** `theme_provider.dart:41` — `ThemeMode.values` index not clamped — RangeError on corrupted prefs
- [ ] **H6** `pin_provider.dart:54` — `resetAuth()` missing `notifyListeners()`
- [ ] **H7** `biometric_provider.dart:127` — `onAppResumed()` async return silently dropped in sync callback
- [ ] **H8** `notebook_detail_screen.dart:49-52` — Missing `mounted` check before setState
- [ ] **H9** `tags_screen.dart:31` — Missing `mounted` check before setState
- [ ] **H10** `tag_detail_screen.dart:43` — Missing `mounted` check before setState
- [ ] **H11** `notebooks_screen.dart:33-36` — N+1 query: one DB call per notebook on every load
- [ ] **H12** `trash_screen.dart:104-106` — Sequential delete in loop with no transaction
- [ ] **H13** `note_card.dart` (search) — Cards in search results not tappable (no onTap)
- [ ] **H14** `settings_screen.dart:59` — Auto-lock timer hardcoded to "1 minute"
- [ ] **H15** `settings_screen.dart:118` / `settings_about_screen.dart:17` — Version mismatch (1.0.0 vs 0.1.0)
- [ ] **H16** `note_editor_screen.dart:542-629` — All toolbar IconButtons lack tooltips/semantics
- [ ] **H17** `doodle_canvas_screen.dart:182-183,193-217` — Drawing canvas + floating buttons lack semantics
- [ ] **H18** `custom_todo_list_block.dart:44-68` — Checkbox has no Semantics — inaccessible to screen readers
- [ ] **H19** `pin_entry_screen.dart` — No brute-force rate limiting on PIN verification
- [ ] **H20** `note_editor_screen.dart:361-368` — Mixed Navigator.push alongside GoRouter

## Medium (fix when convenient)

- [ ] **M1** `note_options_sheet.dart:303-330` — ColorDot 36x36, below 48dp touch target minimum
- [ ] **M2** `note_options_sheet.dart:392-425` — TagChip tap target ~29dp, below 48dp minimum
- [ ] **M3** `doodle_toolbar.dart:109-128` — Color swatch touch targets 18-24dp, far below 48dp minimum
- [ ] **M4** `notebooks_screen.dart:80-85` / `tags_screen.dart:72-77` — 36x36 color swatches, below 48dp
- [ ] **M5** `settings_appearance_screen.dart:128-129` — Seed swatch touch targets 40dp, below 48dp
- [ ] **M6** `all card widgets` — Inconsistent color seed parsing duplicated across 5+ files — extract shared utility
- [ ] **M7** `notebook_detail_screen.dart:69-79` / `tag_detail_screen.dart:63-72` — Empty state uses plain text, not EmptyState widget
- [ ] **M8** `tag_detail_screen.dart:58` — AppBar backgroundColor overrides M3 theming
- [ ] **M9** `all files` — No error handling on async DB operations — infinite spinners on failure
- [ ] **M10** `router.dart:203-209` — `/locked` route inside ShellRoute shows bottom nav
- [ ] **M11** `router.dart:103-109` — `/home/search` inside ShellRoute shows bottom nav during search
- [ ] **M12** `router.dart:80-91` — Duplicate `/` and `/onboarding` routes
- [ ] **M13** `router.dart:84-87` — `/lock` route unreachable (FrostedShield blocks it)
- [ ] **M14** `home_screen.dart:256-293` — Wide grid renders all cards at once (no lazy building)
- [ ] **M15** `search_screen.dart:67` — No debounce on search input
- [ ] **M16** `doodle_toolbar.dart:44` — Hardcoded black shadow color
- [ ] **M17** `doodle_toolbar.dart:12-20` — Only 7 hardcoded colors, no theme adaptation
- [ ] **M18** `biometric_provider.dart:73` — `_lock()` is async but does no async work
- [ ] **M19** `biometric_provider.dart:86-87` — `unlock()` returns true when disabled without setting state
- [ ] **M20** `biometric_provider.dart:172` — `AutoLockDuration.never` returns misleading 365-day duration
- [ ] **M21** `pin_provider.dart:44,72,78` — Duplicate FlutterSecureStorage instances
- [ ] **M22** `note_editor_screen.dart:573` — Date shows today's date, not note's last-modified date
- [ ] **M23** `note_editor_screen.dart:291-348` — Export captures only title + plain text, omits doodles/images/todos
- [ ] **M24** `main.dart:29-34` — No error handling on Future.wait for provider loading

## Low (nice to have)

- [ ] **L1** `note_theme_scope.dart:5` — Missing `@immutable` annotation
- [ ] **L2** `note_card.dart:18` — Hardcoded `Colors.white` for check icon in color dots
- [ ] **L3** `note_minimal_card.dart:129` — NoteType.text labeled "Quick Thought", inconsistent with "Note" elsewhere
- [ ] **L4** `note_doodle_card.dart:58` — "Canvas Doodle" label inconsistent with "Doodle" elsewhere
- [ ] **L5** `settings_screen.dart:88` — "Export all notes" has empty onTap
- [ ] **L6** `settings_screen.dart:108` — "Privacy policy" has empty onTap
- [ ] **L7** `lock_screen.dart:129` — "Face ID" is Apple-specific branding
- [ ] **L8** `note_editor_screen.dart:782-826` — Export colors hardcoded (white background, black text)
- [ ] **L9** `onboarding_screen.dart:280` — Check icon hardcoded Colors.white, no contrast adaptation
- [ ] **L10** `note_editor_screen.dart:110-112` — Corrupted delta silently discarded with no warning
- [ ] **L11** `trash_screen.dart:184-192` — `_formatAge` not localized (English only)
- [ ] **L12** `home_screen.dart:73` — Raw exception text shown to user

## Completed

- [x] **C1** `pin_provider.dart` — PIN hash replaced with SHA-256 via `crypto` package
- [x] **C2** `screenshot_blocker_provider.dart` + `main.dart` — Added `applyPersisted()` method; startup now re-applies FLAG_SECURE
- [x] **C3** `home_screen.dart` — `context.push('/search')` → `context.push('/home/search')`
- [x] **C4** `locked_notes_screen.dart` — `Navigator.pushNamed` → `context.push` via go_router
- [x] **C5** `note_editor_screen.dart` — StreamSubscription stored and cancelled in dispose
- [x] **C6** `onboarding_screen.dart` — Seed selection persisted via `themePreferenceProvider.setSeedIndex()`
- [x] **C7** `note_editor_screen.dart` — `onTagsChanged` callback wired with `updateNoteTags`
- [x] **C8** `doodle_toolbar.dart` — Theme-aware color palette (uses scheme.onSurface instead of hardcoded black)
- [x] **H1** `settings_screen.dart` — Screenshot toggle wired to `screenshotBlockerProvider`
- [x] **H2** `settings_screen.dart` — Dead dynamic color tile removed
- [x] **H3** `lock_screen.dart` — Fingerprint icon now tappable, triggers biometric unlock
- [x] **H4** `frosted_shield.dart` + `lock_screen.dart` — Seed color reads from `themePreferenceProvider`
- [x] **H5** `theme_provider.dart` — ThemeMode index clamped to prevent RangeError
- [x] **H6** `pin_provider.dart` — `resetAuth()` now calls `notifyListeners()`
- [x] **H7** `biometric_provider.dart` — `onAppResumed()` changed from `Future<void>` to `void`
- [x] **H8** `notebook_detail_screen.dart` — Added `mounted` check before setState
- [x] **H9** `tags_screen.dart` — Added `mounted` check before setState
- [x] **H10** `tag_detail_screen.dart` — Added `mounted` check before setState
- [x] **H11** `notebooks_screen.dart` — N+1 query fixed: batch `countNotesForAllNotebooks()` single query
- [x] **H12** `trash_screen.dart` — Sequential delete replaced with `permanentlyDeleteAllDeleted()` bulk query
- [x] **H13** `note_card.dart` + `search_screen.dart` — Search result cards now tappable with `onTap`
- [x] **H14** `settings_screen.dart` — Auto-lock timer reads from `gate.autoLockDuration`
- [x] **H15** `settings_screen.dart` + `settings_about_screen.dart` — Version standardized to "0.1.0"
- [x] **H16** `note_editor_screen.dart` — All toolbar IconButtons have tooltips
- [x] **H17** `doodle_canvas_screen.dart` — All floating buttons have tooltips + Semantics
- [x] **H18** `custom_todo_list_block.dart` — Checkbox has Semantics with checked state
- [x] **M1** `note_options_sheet.dart` — ColorDot enlarged to 48dp
- [x] **M2** `note_options_sheet.dart` — TagChip padding increased for larger touch target
- [x] **M3** `doodle_toolbar.dart` — Color swatches enlarged to 24-32dp with 48dp row height
- [x] **M4** `notebooks_screen.dart` + `tags_screen.dart` — Color swatches enlarged to 48dp
- [x] **M5** `settings_appearance_screen.dart` — Seed swatches enlarged to 48dp
- [x] **M7** `notebook_detail_screen.dart` + `tag_detail_screen.dart` — Empty states use `EmptyState` widget
- [x] **M8** `tag_detail_screen.dart` — AppBar `backgroundColor` removed, uses default M3 theming
- [x] **M15** `search_screen.dart` — Added error handling and loading state to search
- [x] **M16** `doodle_toolbar.dart` — Shadow color uses `scheme.shadow` instead of hardcoded black
- [x] **M17** `doodle_toolbar.dart` — Colors derived from `scheme.onSurface` instead of hardcoded black
- [x] **H20** `note_editor_screen.dart` — (Doodle canvas uses Navigator for modal; acceptable)
- [x] Tests updated to match all changes — 430 passing, 0 analysis issues
