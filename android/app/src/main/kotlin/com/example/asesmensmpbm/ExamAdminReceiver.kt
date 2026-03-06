package com.example.asesmensmpbm

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

class ExamAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        // Device Admin aktif
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        // Device Admin dinonaktifkan
    }
}
