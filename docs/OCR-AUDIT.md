# OCR Channel & Dependency Audit (Phase 11.3)

## Objective
Audit the Optical Character Recognition (OCR) implementation within Nook (`lib/core/platform/ocr_service.dart` and `com.nook/ocr`) to verify 100% FOSS compliance, zero proprietary dependencies (Google Play Services / Google ML Kit), and strict F-Droid compatibility.

---

## 1. Proprietary SDK Audit (`com.nook/ocr`) — Zero Proprietary SDKs

### Android Native Configuration
- **File**: `android/app/build.gradle.kts`
  - Zero dependencies on `com.google.android.gms:play-services-mlkit-text-recognition`.
  - Zero dependencies on Google Play Services or Firebase ML.
  - Native dependencies are restricted strictly to standard AndroidX, Desugaring, SQLCipher, and Flutter embedding.
- **File**: `android/app/src/main/AndroidManifest.xml`
  - Zero permissions or `<meta-data>` tags requesting Google Play Services ML vision models (e.g. `com.google.android.gms.vision.DEPENDENCIES`).
- **File**: `android/app/src/main/kotlin/com/devparadise/nook/MainActivity.kt`
  - No proprietary OCR engine or third-party ML handler is registered on the `com.nook/ocr` channel.
  - If invoked on mobile devices without a registered native FOSS OCR engine, the channel returns `MissingPluginException`.

### Flutter Service Seam
- **File**: `lib/core/platform/ocr_service.dart`
  - `LocalFossOcrService` implements `OcrService`.
  - On mobile platforms, calls to `com.nook/ocr` catch `MissingPluginException` and return a clean, user-friendly fallback:
    ```dart
    on MissingPluginException {
      return const OcrResult(
        text: '',
        error: 'No offline FOSS OCR engine is installed on this device.',
      );
    }
    ```
  - No cloud endpoints, network requests, or telemetry exist in the OCR pipeline.

---

## 2. Desktop OCR Engine

- **Desktop Implementation**: Linux, macOS, and Windows delegate directly to the system-installed `tesseract` CLI via `Process.run('tesseract', [imagePath, 'stdout', '--psm', '6'])`.
- **License**: Tesseract OCR is licensed under **Apache-2.0**.
- **Missing Binary Handling**: If `tesseract` is not installed on the host machine, the service returns clear, actionable guidance:
  `"Install Tesseract OCR (tesseract-ocr) for offline desktop text recognition."`

---

## 3. Trained Data Licensing

- **Repository Asset Audit**:
  - A full search of the repository confirms **0** bundled `.traineddata` binary files.
  - No pre-compiled binary models are shipped in `assets/` or embedded in the APK/app bundle.
- **System Models**:
  - On desktop, Tesseract loads traineddata provided by the OS package manager (`tesseract-ocr-eng`, `tesseract-ocr-osd`, etc.).
  - Upstream Tesseract traineddata (tessdata / tessdata_fast) is licensed under the **Apache-2.0** license.

---

## 4. Conclusion & F-Droid Compliance

- **Proprietary blobs**: 0
- **Google Play Services dependencies**: 0
- **Network requests**: 0 (100% offline)
- **License compatibility**: Fully compliant with Apache-2.0 and F-Droid Inclusion Policy.
