package com.example.jadwal

import android.app.AlarmManager
import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
                "getDownloadDirectory" -> {
                    val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: cacheDir
                    result.success(dir.absolutePath)
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        result.success(installApk(filePath))
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath cannot be null", null)
                    }
                }
                "canInstallUnknownApps" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallUnknownAppsSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "downloadWithDownloadManager" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName") ?: "jadwal-update.apk"
                    val title = call.argument<String>("title") ?: "Jadwal Update"
                    if (url != null) {
                        val downloadId = startSystemDownload(url, fileName, title)
                        result.success(downloadId)
                    } else {
                        result.error("INVALID_ARGUMENT", "url cannot be null", null)
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

    private var downloadReceiver: BroadcastReceiver? = null

    private fun installApk(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists() || file.length() == 0L) {
                return false
            }
            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun startSystemDownload(url: String, fileName: String, title: String): Long {
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val uri = Uri.parse(url)

        val destDir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: cacheDir
        val destFile = File(destDir, fileName)
        if (destFile.exists()) {
            destFile.delete()
        }

        val request = DownloadManager.Request(uri).apply {
            setTitle(title)
            setDescription("Downloading Jadwal update...")
            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            setMimeType("application/vnd.android.package-archive")
            setDestinationInExternalFilesDir(this@MainActivity, Environment.DIRECTORY_DOWNLOADS, fileName)
        }

        val downloadId = dm.enqueue(request)
        registerDownloadReceiver(downloadId, destFile)
        return downloadId
    }

    private fun registerDownloadReceiver(targetId: Long, destFile: File) {
        unregisterDownloadReceiver()

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == DownloadManager.ACTION_DOWNLOAD_COMPLETE) {
                    val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
                    if (id == targetId && destFile.exists()) {
                        installApk(destFile.absolutePath)
                    }
                }
            }
        }
        downloadReceiver = receiver

        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
    }

    private fun unregisterDownloadReceiver() {
        downloadReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
            downloadReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterDownloadReceiver()
        super.onDestroy()
    }
}
