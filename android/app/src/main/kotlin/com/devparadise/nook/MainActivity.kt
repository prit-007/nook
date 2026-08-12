package com.devparadise.nook

import android.Manifest
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.Build
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val WINDOW_CHANNEL = "com.nook/window_manager"
    private val PERMISSIONS_CHANNEL = "com.nook/nearby_permissions"
    private val REQUEST_CODE_NEARBY = 1001

    private var pendingPermissionsResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Window flags channel (screenshot blocker)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WINDOW_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "addFlags" -> {
                    val flags = call.argument<Int>("flags") ?: 0
                    window.addFlags(flags)
                    result.success(null)
                }
                "clearFlags" -> {
                    val flags = call.argument<Int>("flags") ?: 0
                    window.clearFlags(flags)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Nearby permissions channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PERMISSIONS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkNearbyPermissions" -> {
                    result.success(hasNearbyPermissions())
                }
                "requestNearbyPermissions" -> {
                    if (hasNearbyPermissions()) {
                        result.success(true)
                    } else {
                        pendingPermissionsResult = result
                        requestNearbyPermissions()
                    }
                }
                "isWifiEnabled" -> {
                    val wifiManager =
                        applicationContext.getSystemService(WIFI_SERVICE) as? WifiManager
                    result.success(wifiManager?.isWifiEnabled == true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasNearbyPermissions(): Boolean {
        val permissions = getNearbyPermissions()
        return permissions.all { perm ->
            ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun getNearbyPermissions(): List<String> {
        val permissions = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ (API 33)
            permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            // Android 12 and below
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                permissions.add(Manifest.permission.BLUETOOTH_SCAN)
                permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }

        return permissions
    }

    private fun requestNearbyPermissions() {
        val permissions = getNearbyPermissions()
        val missing = permissions.filter { perm ->
            ContextCompat.checkSelfPermission(this, perm) != PackageManager.PERMISSION_GRANTED
        }

        if (missing.isEmpty()) {
            pendingPermissionsResult?.success(true)
            pendingPermissionsResult = null
            return
        }

        ActivityCompat.requestPermissions(this, missing.toTypedArray(), REQUEST_CODE_NEARBY)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == REQUEST_CODE_NEARBY) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionsResult?.success(allGranted)
            pendingPermissionsResult = null
        }
    }
}
