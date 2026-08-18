import com.android.build.gradle.api.ApkVariantOutput
import java.util.Properties

// Per-ABI version codes (F-Droid's required scheme): base versionCode ×10 +
// ABI offset → base 6 = 61 (armeabi-v7a), 62 (arm64-v8a), 63 (x86_64).
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials live in android/key.properties (gitignored).
// When present, release builds are signed with the real store key; otherwise
// they fall back to the debug key so `flutter run --release` keeps working in
// local/dev environments.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.devparadise.nook"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.devparadise.nook"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Sign with the real release key when configured, else debug.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// F-Droid/Play ABI split version codes, matching the `%c * 10 + {1,2,3}` scheme:
// base versionCode 6 → 61 (armeabi-v7a), 62 (arm64-v8a), 63 (x86_64).
//
// This MUST be `applicationVariants.configureEach` (registered after the Flutter
// plugin's own configureEach at FlutterPlugin.kt, which sets `abi*1000+base`):
// configureEach actions run in registration order, so this block runs last and
// wins. `androidComponents.onVariants` runs at a different point in AGP 9 and
// ends up overwritten by the plugin's `abi*1000+base`.
@Suppress("DEPRECATION")
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutput).versionCodeOverride =
                variant.versionCode * 10 + abiVersionCode
        }
    }
}

flutter {
    source = "../.."
}
