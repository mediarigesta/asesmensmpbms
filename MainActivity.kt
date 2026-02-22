package com.example.asesmensmpbms

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bmsexam/kiosk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startKiosk" -> {
                    try {
                        // Screen pinning (App Pinning) — Android 5.0+
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            startLockTask()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("KIOSK_ERROR", e.message, null)
                    }
                }
                "stopKiosk" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            stopLockTask()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("KIOSK_ERROR", e.message, null)
                    }
                }
                "isKioskActive" -> {
                    try {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val isLocked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
                        } else {
                            false
                        }
                        result.success(isLocked)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
