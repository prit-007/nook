package com.devparadise.nook

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nook/window_manager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
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
    }
}
