# Plan Update v2 — Reconciling the Plan Against Real `pub get` Resolution
### Read this alongside the original three docs — this file records what changed and why, it doesn't replace them wholesale.

Your actual resolved `pubspec.yaml` surfaced several real version gaps between what I originally guessed and what pub.dev serves today. Rather than silently rewrite the earlier docs, here's an explicit diff so you know exactly what to distrust in the earlier code samples versus what's now verified against the real package.

---

## 1. AppFlowy Editor — confirmed against the actual v6 repo/docs

**What I verified just now** (from the live changelog and example/documentation files on GitHub):

- `AppFlowyEditor.custom(editorState: ..., blockComponentBuilders: ..., characterShortcutEvents: ...)` is a real, current constructor — the shape of the wiring code in the detailed plan's §6.3 is directionally correct.
- `standardBlockComponentBuilderMap` is still the real, current name for the built-in component map — my `_buildComponentMap()` example spreading `...standardBlockComponentBuilderMap` is accurate.
- The core `appflowy_editor` package's own dependency list (as of v6) now includes `file_picker`, `pdf`, `markdown`, `html`, `universal_html` directly — this is a strong signal that image handling and markdown/HTML import-export moved **into core** in the v4→v6 jump, which lines up with why `appflowy_editor_plugins` disappeared from your resolved pubspec (pub likely couldn't find a v6-compatible release of it, or it was formally folded in and deprecated).

**What this means for the plan:** the custom `doodle` node-type code in Part 3 §1 (the `DoodleBlockWidget`, the `Transaction`-based save-back) is still architecturally correct — custom block types via `BlockComponentBuilder` are a stable, core concept across these versions. But the **built-in `image` block's exact builder class name and constructor params may have changed** between the v4 API I originally described and v6. Before you copy my `Image` slash-menu handler code verbatim, open `example/lib/pages/` in the cloned `appflowy-editor` repo (`git clone https://github.com/AppFlowy-IO/appflowy-editor.git`) and find whichever example page demonstrates image insertion — that's ground truth, not my recollection.

**Action item:** run the example app yourself (`cd appflowy-editor/example && flutter run`) once, before writing your own integration. Fifteen minutes there will save you hours of guessing against a library whose public tutorials mostly target older versions.

---

## 2. Riverpod v3/v4 — this is the change with the most code-shape impact

Your pubspec resolved `flutter_riverpod: ^3.3.2` and `riverpod_annotation: ^4.0.3`. Riverpod 3.x's biggest conceptual change from the v2 code I wrote earlier: **`StateNotifier`/`StateNotifierProvider` are deprecated** in favor of class-based `Notifier`/`AsyncNotifier` with the `@riverpod` code-gen annotation as the now-preferred style.

**Concretely, what needs rewriting from the detailed plan's §4:**

Old (v2-style, what I gave you before — will not compile cleanly against v3):
```dart
class NoteEditorNotifier extends StateNotifier<NoteEditorState> {
  NoteEditorNotifier(this.noteId) : super(NoteEditorState.initial());
  final String noteId;
  // ...
}

final noteEditorProvider = StateNotifierProvider.family<
    NoteEditorNotifier, NoteEditorState, String>(
  (ref, noteId) => NoteEditorNotifier(noteId),
);
```

New (v3-style, code-gen `Notifier`):
```dart
@riverpod
class NoteEditor extends _$NoteEditor {
  @override
  NoteEditorState build(String noteId) {
    return NoteEditorState.initial();
  }

  void updateTitle(String title) {
    state = state.copyWith(title: title);
  }
}

// Usage: ref.watch(noteEditorProvider(noteId))
```

The reactive Drift-stream providers (`notesListProvider`) shift similarly — prefer `@riverpod Stream<List<Note>> notesList(...)` code-gen functions over the old `StreamProvider.family(...)` constructor style, though the constructor style still works in v3, it's just no longer the recommended idiom.

**Action item:** read the official Riverpod 3.x migration guide (search "riverpod migrate stateNotifier to notifier") before writing your first provider — it's a genuinely short read and will save you from writing v2-shaped code that half-compiles against v3's generator.

---

## 3. SQLite/SQLCipher `+eol` tags — investigate before building the DB layer

`sqlite3_flutter_libs: ^0.6.0+eol` and `sqlcipher_flutter_libs: ^0.7.0+eol` both resolved with an explicit end-of-life marker. This is the pub.dev convention a maintainer uses to say "this specific version line is done, don't build new things assuming ongoing patches to it" — it does **not** necessarily mean the whole package is abandoned; it commonly means a renamed/restructured successor exists.

**Action item, in order:**
1. Open `https://pub.dev/packages/sqlite3_flutter_libs` and `https://pub.dev/packages/sqlcipher_flutter_libs` directly and read the top of the README — the maintainer almost always states the replacement path in bold at the top when tagging `+eol`.
2. Check Drift's own current documentation for which SQLite-binding package it now recommends pairing with — since Drift's own maintainers track this closely, their docs are the fastest way to the current correct answer rather than guessing from the tag alone.
3. Don't write any of the `openEncryptedDatabase()` code from the detailed plan's §3 until you've confirmed the current recommended package — the `PRAGMA key = ...` / `PRAGMA cipher_page_size` calls themselves are standard SQLCipher pragmas and will likely still be correct, but the package you call `NativeDatabase.createInBackground` through might have a new name.

---

## 4. `freezed` — pin the stable release, not the resolved dev build

Your file has `freezed: ^3.2.6-dev.1`. **Fix this before your first `build_runner build`:**

```bash
flutter pub add --dev freezed
```
Running `pub add` without a version constraint pulls whatever pub currently considers the best stable match — check the version it writes into your pubspec afterward and confirm it does **not** contain `-dev`, `-alpha`, `-beta`, or `+eol`. If pub still resolves a prerelease as "best match" (unusual, but possible if you have another dependency forcing a prerelease range), explicitly pin the latest stable line yourself, e.g. `freezed: ^3.1.0` — check pub.dev's version list for the actual latest non-prerelease number before typing it in.

---

## 5. `nearby_service: ^0.2.1` — treat this as pre-production-grade, not a settled choice

This resolved meaningfully earlier (pre-1.0) than the `^2.0.2` I originally guessed. A sub-1.0 version on your **riskiest architectural piece** (device sync) changes how you should plan Phase 5 from the master plan:

- **Read the GitHub issues tab, not just the README**, before committing to it — specifically search closed and open issues for "Android 13," "Android 14," "pairing fails," and "disconnect" — Wi-Fi Direct implementations are notoriously flaky across OEM Android skins (Samsung/Xiaomi in particular), and a pre-1.0 package's issue tracker will tell you which devices to expect trouble on far better than the README will.
- **Budget more time for Phase 5 than originally scoped** — the master plan already flagged this as your riskiest phase and told you to prototype transport early; that advice is now more important, not less.
- **Have a fallback plan**: if `nearby_service` proves too unstable in your own two-device testing, the fallback isn't a different package so much as dropping to a lower-level primitive — `flutter_p2p_connection` or hand-rolling on top of Android's native `WifiP2pManager` via platform channels are the realistic escape hatches, both meaningfully more work. Worth knowing this exists as an option now rather than discovering it mid-Phase-5.

---

## 6. Package Version Table — corrected, with a verification note on each risky one

| Package | Plan v1 guess | Your actual resolved version | Status |
|---|---|---|---|
| `flutter_riverpod` | ^2.6.1 | ^3.3.2 | ⚠️ Provider code-shape changed, see §2 |
| `riverpod_annotation` | ^2.6.1 | ^4.0.3 | ⚠️ Paired with above |
| `go_router` | ^14.6.2 | ^17.4.0 | Routing API has stayed fairly stable across major bumps historically — the route table/skeleton in Part 3 §3 is likely still directionally correct, but re-check `redirect`/`ShellRoute` signatures against v17 docs before pasting |
| `drift` | ^2.22.1 | ^2.22.1 | ✅ matched |
| `sqlite3_flutter_libs` | ^0.5.28 | ^0.6.0+eol | ⚠️ See §3 |
| `sqlcipher_flutter_libs` | ^0.6.4 | ^0.7.0+eol | ⚠️ See §3 |
| `appflowy_editor` | ^4.0.0 | ^6.2.0 | ⚠️ Core concepts confirmed stable, see §1 |
| `appflowy_editor_plugins` | ^1.0.0 | *(removed — no compatible version found)* | Likely folded into core, see §1 |
| `local_auth` | ^2.3.0 | ^3.0.2 | Re-check before use, not yet verified |
| `flutter_secure_storage` | ^9.2.2 | ^10.3.1 | Re-check before use, not yet verified |
| `nearby_service` | ^2.0.2 | ^0.2.1 | ⚠️ Much earlier/riskier than assumed, see §5 |
| `share_plus` | ^10.1.3 | ^12.0.2 | Re-check before use, not yet verified |
| `intl` | ^0.19.0 | ^0.20.3 | Low risk, minor version drift |
| `freezed` | ^2.5.7 | ^3.2.6-dev.1 | ⚠️ Fix pin, see §4 |
| `riverpod_generator` | ^2.6.3 | ^4.0.4 | Paired with §2 |
| `flutter_lints` | ^5.0.0 | ^6.0.0 | Low risk |

**The honest summary:** roughly a third of the stack drifted meaningfully in the time between when I first wrote the plan and when you actually ran `pub get`. That's not a sign anything went wrong on your end — it's the expected cost of planning against a fast-moving FOSS ecosystem in a text conversation rather than a live terminal. The fix going forward (see §7) is to keep using `flutter pub add` as your source of truth for version numbers rather than trusting any version string I write in prose.

---

## 7. Process Change Going Forward

Rather than me writing pinned version numbers into planning docs (which visibly went stale within one conversation), the reliable workflow from here is:

1. I describe **what package to add and why** (the architectural reasoning stays valid far longer than version numbers do).
2. You run `flutter pub add <package>` yourself to get the real current version.
3. For any code sample I give you against a specific package's API (not just "add this dependency"), treat it as **the shape of the solution** — verify method/class names against that package's actual current docs or example app before pasting into your project, exactly like we just did for AppFlowy Editor.
4. When something doesn't compile against what you actually have installed, paste me the real error — like you did with the `palette_generator` constraint error — and I'll fix it against your real, current dependency graph rather than my possibly-stale assumption.

This is genuinely a healthier way to build against a fast-moving FOSS stack than trying to get every version number right in a planning document up front — keep doing what you just did (running commands, pasting real errors and real resolved files back to me) and we'll keep the plan honest as you go.