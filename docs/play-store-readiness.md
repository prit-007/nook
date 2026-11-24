# Play Store Readiness & Data Safety Guide

This document specifies the exact configurations, declarations, and commands required for releasing **nook.** to the Google Play Store.

---

## 1. Google Play Data Safety Form

Google Play requires all apps to declare their data collection and sharing practices. Because Nook is **100% local-first with zero telemetry, zero trackers, and zero cloud services**, the Data Safety submission is straightforward and serves as a key privacy trust factor.

### Question-by-Question Declaration

| Section | Question | Answer | Notes / Rationale |
| :--- | :--- | :--- | :--- |
| **Data Collection** | Does your app collect or share any of the required user data types? | **No** | No user data is sent off the device to any server. |
| **Data Sharing** | Does your app share any user data with third parties? | **No** | No third-party SDKs, analytics, advertising, or cloud sync exist. |
| **Data Transfer Encryption** | Is all user data collected by your app encrypted in transit? | **Yes (N/A — Local P2P only)** | All local peer-to-peer sync (UDX/libp2p) uses Noise protocol channel encryption. |
| **Data Deletion** | Do you provide a way for users to request data deletion? | **Yes** | Deleting a note purges it locally; uninstalling the app permanently deletes the SQLCipher encrypted database and platform keystore key. |
| **Account Creation** | Does your app require an account? | **No** | Completely offline; no account or sign-in mechanism. |

### Ephemeral Data Processing Exceptions
- **Camera (`CAMERA`)**: Used solely for scanning QR codes during P2P sync pairing. Frames are evaluated in-memory in real time and are never recorded, cached to disk, or transmitted.
- **Biometrics (`USE_BIOMETRIC`)**: Handled completely by Android's `BiometricPrompt` system framework. Raw biometric data never touches the app.

---

## 2. Android API Level & 64-Bit Architecture Compliance

Configured in `android/app/build.gradle.kts`:

- **Target SDK**: `targetSdk = 36` (Google Play requires target SDK 34+).
- **Compile SDK**: `compileSdk = 36`.
- **Min SDK**: Flutter default (`minSdk = 21`).
- **Core Library Desugaring**: Enabled via `desugar_jdk_libs:2.1.4` for Java 8+ time APIs on older devices.
- **64-bit Compliance**: Supported ABI configurations include:
  - `arm64-v8a` (Primary modern Android target)
  - `x86_64` (Chromebooks & modern emulators)
  - `armeabi-v7a` (Legacy 32-bit devices)

---

## 3. Permissions & Runtime Rationales

Declared in `android/app/src/main/AndroidManifest.xml`:

| Permission | Category | Purpose & Justification |
| :--- | :--- | :--- |
| `android.permission.INTERNET` | Normal | Local P2P sync socket binding over Wi-Fi / UDX transport. Never connects to external cloud servers. |
| `android.permission.ACCESS_NETWORK_STATE` | Normal | Determines whether the device is connected to a local Wi-Fi network for sync. |
| `android.permission.CHANGE_WIFI_MULTICAST_STATE` | Normal | Required for mDNS peer discovery (`_syncnotenet._udp`). |
| `android.permission.CHANGE_WIFI_STATE` | Normal | Wi-Fi Direct cross-network sync negotiation. |
| `android.permission.ACCESS_WIFI_STATE` | Normal | Identifies active LAN interface for mDNS discovery. |
| `android.permission.NEARBY_WIFI_DEVICES` | Dangerous (`neverForLocation`) | Android 13+ local device discovery without prompting for coarse/fine location. |
| `android.permission.CAMERA` | Dangerous | Scanning pairing QR codes during P2P sync. |
| `android.permission.POST_NOTIFICATIONS` | Dangerous | Android 13+ local note reminder notifications scheduled by the user. |
| `android.permission.SCHEDULE_EXACT_ALARM` | Normal / Special | Delivers exact-time alarms for user-created note reminders. |
| `android.permission.USE_EXACT_ALARM` | Normal | Android 14+ exact alarm delivery for user reminders. |

---

## 4. Release Build Commands

### Google Play Android App Bundle (.aab)
```bash
# Clean and prepare code generation
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Build release App Bundle with code obfuscation and debug symbols
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```
The resulting `.aab` file will be generated at:
`build/app/outputs/bundle/release/app-release.aab`.

### Signing Configuration
Signing credentials must be placed in `android/key.properties` (which is `.gitignore`d):
```properties
storePassword=<keystore-password>
keyPassword=<key-password>
keyAlias=<key-alias>
storeFile=<path-to-keystore-file>
```

---

## 5. Store Listing Metadata

### App Details
- **App Name**: `nook.` (or `Nook: Private Notes & Sync`)
- **Short Description (80 characters)**:
  `Private, encrypted, local-first notes with peer-to-peer sync. Zero cloud.`
- **Category**: Productivity / Tools
- **Content Rating**: Everyone

### Full Description
```markdown
nook. is a private, encrypted, local-first notebook designed for thoughts, checklists, and doodles.

🔒 ZERO CLOUD, ZERO TRACKING
Your thoughts belong to you. Nook has no accounts, no cloud servers, and no trackers. All data stays strictly on your physical device, encrypted with SQLCipher. Encryption keys are securely stored in your device's hardware-backed keystore.

⚡ PEER-TO-PEER NEARBY SYNC
Sync notes directly between your devices over your local Wi-Fi or Wi-Fi Direct. No internet connection or third-party servers required. Device identity is cryptographically verified via noise-encrypted peer-to-peer transport.

📝 RICH CAPTURE & CREATIVE DOODLES
- Full-featured rich text editor with markdown shortcuts (#, -, [], >) and slash commands (/)
- Structured checklists with celebration micro-copy
- Smooth pen, highlighter, and eraser doodles with shape recognition (snapping lines, rectangles, triangles, stars)
- Custom callouts, collapsible sections, code blocks with syntax styling, and document outline
- Inter-note linking ([[note]]) and backlinks discovery

📂 NO LOCK-IN EVER
Export your entire vault anytime as a .nook archive or as standard Markdown and HTML with embedded images. Import from Markdown files or restore your full archive on a fresh device.

⏰ LOCAL REMINDERS & AUTOMATIC TRASH
- Schedule offline reminders and alarms directly on notes
- 30-day soft-delete trash with automatic cleanup and one-tap restore
- Biometric lock (fingerprint/face) and customizable auto-lock timer
```
