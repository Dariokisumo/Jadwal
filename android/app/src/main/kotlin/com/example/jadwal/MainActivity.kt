package com.example.jadwal

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.jadwal/exact_alarm"
    private var pendingDeepLink: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDeepLink(intent)
    }

    private fun handleDeepLink(intent: Intent?) {
        if (intent == null) return

        var url: String? = null

        // 1. Check intent.data URI (e.g. jadwal://profile?data=... or https://dariokisumo.github.io/p#...)
        val data = intent.data
        if (data != null && (data.scheme == "jadwal" || data.scheme == "https" || data.scheme == "http")) {
            url = data.toString()
        }

        // 2. Check Android Intent extras (e.g. intent launched with S.data=... or S.payload=...)
        if (url == null) {
            val extraData = intent.getStringExtra("data")
                ?: intent.getStringExtra("payload")
                ?: intent.getStringExtra("profile")
                ?: intent.extras?.getString("data")
            if (!extraData.isNullOrBlank()) {
                url = if (extraData.startsWith("jadwal:") ||
                    extraData.startsWith("http://") ||
                    extraData.startsWith("https://") ||
                    extraData.startsWith("JADWAL_PROFILE:")) {
                    extraData
                } else {
                    "jadwal://profile?data=$extraData"
                }
            }
        }

        // 3. Check ACTION_SEND with text/plain (direct text/link shared into Jadwal)
        if (url == null && intent.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (!sharedText.isNullOrBlank()) {
                url = sharedText.trim()
            }
        }

        if (url != null) {
            pendingDeepLink = url
            methodChannel?.invokeMethod("onDeepLink", url)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
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
                "getAppVersion" -> {
                    result.success(getAppVersion())
                }
                "getInitialDeepLink" -> {
                    val link = pendingDeepLink
                    pendingDeepLink = null
                    result.success(link)
                }
                "shareText" -> {
                    val text = call.argument<String>("text")
                    val title = call.argument<String>("title") ?: "Share Timing Profile"
                    if (text != null) {
                        shareText(text, title)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Text cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun shareText(text: String, title: String) {
        try {
            val sendIntent = Intent().apply {
                action = Intent.ACTION_SEND
                putExtra(Intent.EXTRA_TEXT, text)
                type = "text/plain"
            }
            val shareIntent = Intent.createChooser(sendIntent, title)
            startActivity(shareIntent)
        } catch (_: Exception) {}
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

    private fun getAppVersion(): String {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            packageInfo.versionName ?: ""
        } catch (_: Exception) {
            ""
        }
    }
}
