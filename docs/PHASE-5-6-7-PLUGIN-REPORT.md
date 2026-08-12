# Plugin Research Report — Phases 5, 6, 7

Generated: August 2026 | Flutter 3.44.8 | Dart >=3.6.0

---

## Phase 5: Nearby Sync

### nearby_service ^0.2.1
- **Already in pubspec** (Phase 0 dependency)
- Wraps Google Nearby Connections API (P2P_STAR / CLUSTER_STAR)
- Supports advertising, discovering, sending/receiving bytes + files
- **Caveat:** ~2 years since last commit, but Nearby Connections API itself is stable
- **Migration:** When `nearby_service` is updated or forked, remove keyboard_height_plugin-style patches

### flutter_nearby_connections_plus
- Community fork, more actively maintained
- Same underlying API (Google Nearby Connections)
- Better null safety, newer AndroidX deps
- **Recommendation:** Consider as replacement if nearby_service stays stale

### nsd (Network Service Discovery)
- mDNS / Bonjour-based, no Google dependency
- Good for local WiFi discovery without Nearby API overhead
- **Caveat:** Requires `>=3.10.0` (satisfied after SDK bump)
- No iOS App Store issues (uses system NSNetService)

### permission_handler (REJECTED)
- Known AGP 9 compatibility issues — Gradle metadata conflicts
- Confirmed by user decision: use **custom MethodChannel** instead
- Already implemented: `NearbyPermissions` class + Kotlin handler in MainActivity

### connectivity_plus
- Network state monitoring (WiFi, mobile, none)
- Useful for sync trigger (start sync when WiFi connected)
- Lightweight, well-maintained by fluttercommunity

### network_info_plus
- Get SSID, BSSID, IP address
- Useful for device identification in sync
- Pair with connectivity_plus for full network awareness

---

## Phase 6: App Hardening & Export

### sentry_flutter (REJECTED)
- Full crash reporting + performance monitoring
- **Rejected per user decision:** "zero telemetry" — local log file only
- Alternative: implement `lib/core/crash/crash_reporter.dart` with local file logging

### home_widget
- iOS: WidgetKit | Android: Glance/App Widgets
- Could show pinned notes on home screen
- Medium complexity, good for Phase 7 polish

### archive ^3.6.1 (ADDED)
- Pure Dart, no native dependencies
- ZIP creation/extraction for `.nook` archive format
- **Already added to pubspec** as Phase 6 foundation
- Supports tar, gzip, bzip2 as well

### printing
- PDF generation from Flutter widgets
- **Caveat:** `>=3.11.0` requirement — not yet available (Dart SDK is >=3.6.0)
- Alternative: `pdf` package (pure Dart) or `flutter_html_to_pdf`

### flutter_local_notifications
- Scheduled notifications, channels, permissions
- Good for reminder features (Phase 7)
- Well-maintained, extensive platform support

---

## Phase 7: UI Polish & Advanced Features

### home_widget
- See Phase 6 section above
- Priority: Medium — defer to Phase 7 final polish

### speech_to_text
- Voice-to-text for dictation
- Requires microphone permission (custom MethodChannel can handle)
- Good for Phase 7 accessibility features

### google_mlkit_text_recognition
- On-device OCR for image text extraction
- Could power "search text in photos" feature
- Larger binary size impact (~15MB)
- Consider as optional/future feature

### flutter_mesh_network
- Bluetooth mesh networking
- **Overkill for sync** — Nearby Connections already handles this
- Only consider if Nearby API proves insufficient

---

## Version Compatibility Matrix

| Package | Min Dart | Max Dart | AGP 9 | Notes |
|---------|----------|----------|-------|-------|
| nearby_service | 3.0.0 | 4.0.0 | ✅ | Stale but functional |
| flutter_nearby_connections_plus | 3.0.0 | 4.0.0 | ✅ | Better maintained |
| nsd | 3.10.0 | 4.0.0 | ✅ | mDNS alternative |
| device_info_plus | 3.6.0 | 4.0.0 | ✅ | Pinned to ^11.5.0 |
| archive | 3.6.0 | 4.0.0 | ✅ | Pure Dart |
| connectivity_plus | 3.0.0 | 4.0.0 | ✅ | Network state |
| home_widget | 3.0.0 | 4.0.0 | ✅ | Future phase |
| flutter_local_notifications | 3.0.0 | 4.0.0 | ✅ | Reminders |

---

## Recommendations

1. **Phase 5 transport:** Stick with `nearby_service ^0.2.1` for now; plan migration to `flutter_nearby_connections_plus` if issues arise
2. **Permissions:** Custom MethodChannel already implemented — do not add `permission_handler`
3. **Crash reporting:** Local file only, no Sentry
4. **Export format:** Use `archive ^3.6.1` for `.nook` ZIP bundles
5. **PDF export:** Use `pdf` package (pure Dart) instead of `printing` until Dart 3.11+
6. **OCR:** Defer to post-MVP — significant binary size impact
