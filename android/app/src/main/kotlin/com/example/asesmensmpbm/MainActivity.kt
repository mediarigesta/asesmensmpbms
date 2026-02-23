package com.example.asesmensmpbm

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val KIOSK_CHANNEL = "com.bmsexam/kiosk"
    private var kioskActive = false
    private val handler = Handler(Looper.getMainLooper())

    private lateinit var dpm: DevicePolicyManager
    private lateinit var adminComponent: ComponentName

    private val enforceRunnable = object : Runnable {
        override fun run() {
            if (!kioskActive) return
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    window.insetsController?.hide(
                        android.view.WindowInsets.Type.statusBars() or
                        android.view.WindowInsets.Type.navigationBars()
                    )
                } else {
                    @Suppress("DEPRECATION")
                    window.decorView.systemUiVisibility = (
                        android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        or android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                        or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    )
                }
            } catch (_: Exception) {}
            handler.postDelayed(this, 300)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, ExamAdminReceiver::class.java)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            KIOSK_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "startKiosk" -> {
                    // Harus di main thread
                    runOnUiThread {
                        kioskActive = true
                        val isAdmin = dpm.isAdminActive(adminComponent)

                        if (!isAdmin) {
                            // Tampilkan dialog Device Admin
                            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                                putExtra(
                                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                    "BM-Exam membutuhkan izin ini untuk mengunci layar selama ujian berlangsung dan mencegah kecurangan."
                                )
                            }
                            startActivity(intent)
                        }

                        // Window flags
                        window.addFlags(
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                        )

                        // Screen Pinning
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                startLockTask()
                            }
                        } catch (_: Exception) {}

                        // Enforcement loop
                        handler.removeCallbacks(enforceRunnable)
                        handler.post(enforceRunnable)

                        result.success(isAdmin)
                    }
                }

                "stopKiosk" -> {
                    runOnUiThread {
                        kioskActive = false
                        handler.removeCallbacks(enforceRunnable)
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                stopLockTask()
                            }
                        } catch (_: Exception) {}
                        window.clearFlags(
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        )
                        result.success(true)
                    }
                }

                "isAdminActive" -> {
                    result.success(dpm.isAdminActive(adminComponent))
                }

                "isKioskActive" -> {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val locked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
                    } else false
                    result.success(locked || kioskActive)
                }

                else -> result.notImplemented()
            }
        }
    }

    // Tombol HOME → paksa kembali ke foreground
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (!kioskActive) return
        handler.postDelayed({
            try {
                @Suppress("DEPRECATION")
                (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
                    .moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
            } catch (_: Exception) {}
        }, 100)
    }

    // Kehilangan fokus → rebut kembali
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!kioskActive) return
        if (!hasFocus) {
            handler.postDelayed({
                try {
                    @Suppress("DEPRECATION")
                    (getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager)
                        .moveTaskToFront(taskId, 0)
                } catch (_: Exception) {}
            }, 150)
        } else {
            enforceRunnable.run()
        }
    }

    // Blokir back button
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (kioskActive) return
        super.onBackPressed()
    }

    override fun onDestroy() {
        handler.removeCallbacks(enforceRunnable)
        super.onDestroy()
    }
}
