package com.example.jadwal

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PeriodicRefreshReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_PERIODIC_REFRESH = "com.example.jadwal.PERIODIC_REFRESH"
        private const val REQUEST_CODE = 7702
        private const val INTERVAL_MS = 5 * 60 * 1000L

        fun schedulePeriodicRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val intent = Intent(context, PeriodicRefreshReceiver::class.java).apply {
                action = ACTION_PERIODIC_REFRESH
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            alarmManager.setInexactRepeating(
                AlarmManager.RTC,
                System.currentTimeMillis() + INTERVAL_MS,
                INTERVAL_MS,
                pendingIntent
            )
        }

        fun cancelPeriodicRefresh(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, PeriodicRefreshReceiver::class.java).apply {
                action = ACTION_PERIODIC_REFRESH
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == ACTION_PERIODIC_REFRESH) {
            JadwalGlanceWidget().forceUpdate(context)
        }
    }
}
