pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

// Patch keyboard_height_plugin's compileSdkVersion before any project is evaluated.
// The plugin (transitive dep of appflowy_editor ^6.2.0) ships compileSdkVersion 31
// which fails AAR metadata checks on AGP 9+. Its own buildscript locks compileSdk
// before any root-level Gradle hook can override it, so we patch the file during
// settings evaluation — before Gradle reads any subproject build scripts.
// Remove once appflowy_editor bumps keyboard_height_plugin to >=0.3.0.
run {
    val pubCache = file(System.getProperty("user.home") + "/.pub-cache/hosted/pub.dev")
    if (pubCache.isDirectory) {
        pubCache.listFiles()
            ?.filter { it.isDirectory && it.name.startsWith("keyboard_height_plugin-") }
            ?.forEach { dir ->
                val buildFile = java.io.File(dir, "android/build.gradle")
                if (buildFile.exists()) {
                    val content = buildFile.readText()
                    if (content.contains("compileSdkVersion 31")) {
                        buildFile.writeText(
                            content.replace("compileSdkVersion 31", "compileSdkVersion 34"),
                        )
                    }
                }
            }
    }
}
