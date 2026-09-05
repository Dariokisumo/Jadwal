-dontoptimize
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class android.app.BroadcastReceiver { *; }

# Glance AppWidgets
-keep class androidx.glance.** { *; }
-keep class com.example.jadwal.JadwalWidgetReceiver { *; }
-keep class com.example.jadwal.JadwalGlanceWidget { *; }
-keep class com.example.jadwal.MidnightReceiver { *; }

# Compose
-dontwarn androidx.compose.**
-keep class androidx.compose.** { *; }
