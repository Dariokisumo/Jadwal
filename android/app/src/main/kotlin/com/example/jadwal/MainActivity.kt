package com.example.jadwal

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.jadwal/exact_alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canScheduleExactAlarms" -> {
                    result.success(canScheduleExactAlarms())
                }
                "requestExactAlarm" -> {
                    result.success(requestExactAlarm())
                }
                "scheduleMidnightAlarm" -> {
                    MidnightReceiver.scheduleNextMidnight(this)
                    result.success(true)
                }
                "schedulePeriodicRefresh" -> {
                    PeriodicRefreshReceiver.schedulePeriodicRefresh(this)
                    result.success(true)
                }
                "getDeviceArchitecture" -> {
                    result.success(getDeviceArchitecture())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getDeviceArchitecture(): String {
        val supported64 = Build.SUPPORTED_64_BIT_ABIS
        if (supported64 != null && supported64.isNotEmpty()) {
            return "arm64"
        }
        val supportedAbis = Build.SUPPORTED_ABIS
        if (supportedAbis != null && supportedAbis.isNotEmpty()) {
            val primary = supportedAbis[0].lowercase()
            if (primary.contains("arm64") || primary.contains("aarch64")) {
                return "arm64"
            }
            if (primary.contains("arm") || primary.contains("v7a")) {
                return "arm32"
            }
            if (primary.contains("x86_64")) {
                return "arm64"
            }
        }
        return "arm32"
    }

    private fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }

    private fun requestExactAlarm(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return true
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (alarmManager.canScheduleExactAlarms()) {
            return true
        }

        // Open the per-app "Alarms & reminders" settings page directly.
        // Without the package URI, ACTION_REQUEST_SCHEDULE_EXACT_ALARM opens the
        // generic list which does NOT show this app on Android 14+.
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (_: Exception) {
            // Fallback: open the generic app-details settings page
            try {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                }
                startActivity(intent)
            } catch (_: Exception) {}
        }
        return false
    }
}
