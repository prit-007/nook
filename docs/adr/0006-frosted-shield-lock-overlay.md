# 6. Frosted Shield lock overlay (over redirect)

Date: 2026-08-09

## Status
Accepted

## Context
The app locks behind a biometric gate when enabled. The original plan
(`notes-app-part3-editor-routes-libraries.md` §3) used a `/lock` route plus a
GoRouter `redirect` callback that bounced any non-`/lock` location to `/lock`
while locked. Redirects couple security to the router, and a redirect-based gate
has drawbacks:

- Every route (including deep links, `fullscreenDialog` pushes, and the editor)
  must be carved out of the redirect predicate, which is easy to get wrong and
  easy to regress.
- Redirecting tears down/rebuilds the underlying widget tree, so app state under
  the lock can be lost or flicker on every unlock.
- A lock that unmounts the screen behind it gives away layout/content via a
  flash frame before the `/lock` screen paints.

We needed a lock that (a) covers 100% of the UI with zero per-route work,
(b) preserves the widget tree beneath it, and (c) reads as "frosted privacy"
rather than a jarring screen swap.

## Decision
Use an always-mounted `FrostedShield` widget stacked above every route in
`MaterialApp.router.builder`, instead of a `/lock` route + redirect.

- `NookApp` is a `ConsumerStatefulWidget` with a `WidgetsBindingObserver`
  (`lib/app.dart`).
- `MaterialApp.router.builder: (context, child) => Stack(children: [child!, FrostedShield()])`.
- `FrostedShield` (`lib/features/security/frosted_shield.dart`) watches
  `biometricGateProvider`; when unlocked it returns `SizedBox.shrink()`, when
  locked it paints an opaque, blur-behind (`BackdropFilter`) shield with a pulsing
  fingerprint and triggers `unlock()` on tap.
- `BiometricGate` (`lib/core/providers/biometric_provider.dart`):
  - injectable `BiometricAuthenticator` seam for tests;
  - `enabled` persisted in SharedPreferences (`biometric_enabled`);
  - lifecycle relock on app resume via `onAppResumed()`;
  - `isLocked => enabled && state == AppLockState.locked`.
- No router or per-screen changes are required to gate content.

## Consequences
- Every route is gated with no redirect predicate to maintain.
- Widget tree/scroll state survives under the lock; unlock is a pure overlay fade.
- The shield always sits in the tree (returns `SizedBox.shrink()` when open), so
  widget tests assert on its *absence* via `find.byType(BackdropFilter)` /
  fingerprint icon, not by checking `FrostedShield` presence.
- `/lock` route and `LockScreen` from the old plan are dropped; the plan doc
  notes this in §3.1/§3.2.
- If a PIN fallback is added later, it plugs into the shield's tap-to-unlock path
  rather than the router.
