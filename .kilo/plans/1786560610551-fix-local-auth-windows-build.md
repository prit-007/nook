# Fix `flutter build windows --release` — `local_auth_windows` MSVC coroutine error

## Problem
`flutter build windows --release` fails while compiling the `local_auth_windows` plugin:
```
error C2338: static assertion failed: 'error STL1011: The /await compiler option,
<experimental/coroutine>, <experimental/generator>, and <experimental/resumable>
are deprecated by Microsoft and will be REMOVED SOON...'
```
Root cause: `local_auth_windows 2.0.1` passes `/await` in its `windows/CMakeLists.txt`
(line 66) and uses `co_await` / `winrt::fire_and_forget`. Newer MSVC toolchains
turn the deprecation warning into a hard error inside `<experimental/coroutine>`.

## Fix plan (smallest reversible patch, consistent with existing repo pattern)
The repo already patches pub-cache plugins during toolchain evaluation
(`android/settings.gradle.kts` patches `keyboard_height_plugin`). Apply the same
pattern here: add a pub-cache patch script for Windows that adds the MSVC silence
define to `local_auth_windows`’ CMake target before CMake config runs.

### Step 1
Add a Dart script at `tool/patch_local_auth_windows_windows.dart` (or a `.ps1` /
shell equivalent) that:
- Locates `~/.pub-cache/hosted/pub.dev/local_auth_windows-*/windows/CMakeLists.txt`
- Appends `_SILENCE_EXPERIMENTAL_COROUTE_DEPRECATION_WARNINGS` to the plugin
  target’s `target_compile_definitions` **and** the test target’s
  `target_compile_definitions`.
- Is idempotent (only patch if not already present).

### Step 2
Invoke the patch script during the Windows build setup so it runs before CMake
configures plugins. Options (pick one, with recommendation A):
- **A (recommended):** Add a post-`flutter pub get` hook in CI and a manual
  step in local build instructions (AGENTS.md / README), similar to the existing
  `tool/patch_appflowy_editor.dart` step.
- **B:** Patch from the app’s `windows/CMakeLists.txt` during build-tree
  configuration by scanning the pub-cache path and rewriting the file in an
  `execute_process` step before `include(flutter/generated_plugins.cmake)`.

### Step 3
Re-run `flutter build windows --release` and verify the plugin compiles and the
app links.

## Why this approach
- `local_auth_windows` still needs `/await` for `co_await`/`winrt::fire_and_forget`
  in 2.0.1; switching to C++20 `<coroutine>` is a plugin upstream change.
- Defining `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` is the
  Microsoft-recommended temporary suppression.
- Patching pub-cache is already an accepted pattern in this repo (documented in
  `AGENTS.md`), and it avoids forking or vendoring the plugin.

## Rollback / removal
Once `local_auth_windows` publishes a version that drops `/await` or updates its
MSVC compatibility, remove the patch script and the CI/local invocation step.
