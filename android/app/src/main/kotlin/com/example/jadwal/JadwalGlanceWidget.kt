package com.example.jadwal

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import org.json.JSONObject

class JadwalGlanceWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val widgetDataJson = prefs.getString("flutter.widget_data", null)

        val widgetData = if (widgetDataJson != null) {
            try {
                parseWidgetData(widgetDataJson)
            } catch (e: Exception) {
                WidgetData.Error("Failed to parse data")
            }
        } else {
            WidgetData.NoTimetable
        }

        provideContent {
            GlanceTheme {
                WidgetContent(widgetData)
            }
        }
    }

    fun forceUpdate(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisWidget = ComponentName(context, JadwalWidgetReceiver::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
        val intent = Intent(context, JadwalWidgetReceiver::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        }
        context.sendBroadcast(intent)
    }

    private fun JSONObject.optStringOrNull(key: String): String? {
        return if (has(key) && !isNull(key)) optString(key) else null
    }

    private fun parseWidgetData(json: String): WidgetData {
        val obj = JSONObject(json)
        return when (obj.getString("type")) {
            "loading" -> WidgetData.Loading
            "no_timetable" -> WidgetData.NoTimetable
            "today" -> WidgetData.Today(
                dayName = obj.getString("dayName"),
                periodCount = obj.getInt("periodCount"),
                currentPeriod = obj.optStringOrNull("currentPeriod"),
                nextPeriod = obj.optStringOrNull("nextPeriod"),
                timeUntilNext = obj.optStringOrNull("timeUntilNext")
            )
            "no_classes_today" -> WidgetData.NoClassesToday(
                dayName = obj.getString("dayName")
            )
            "error" -> WidgetData.Error(
                message = obj.getString("message")
            )
            else -> WidgetData.Error("Unknown state")
        }
    }

    @Composable
    private fun WidgetContent(data: WidgetData) {
        val widgetColorProvider = ColorProvider(day = Color.White, night = Color(0xFF1A1A1A))
        val context = androidx.glance.LocalContext.current
        val componentName = ComponentName(context, MainActivity::class.java)
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .padding(14.dp)
                .background(widgetColorProvider)
                .clickable(actionStartActivity(componentName)),
            contentAlignment = Alignment.Center
        ) {
            when (data) {
                is WidgetData.Loading -> LoadingContent()
                is WidgetData.NoTimetable -> NoTimetableContent()
                is WidgetData.Today -> TodayContent(data)
                is WidgetData.NoClassesToday -> NoClassesContent(data)
                is WidgetData.Error -> ErrorContent(data)
            }
        }
    }

    @Composable
    private fun LoadingContent() {
        Text(
            text = "Loading...",
            style = TextStyle(
                fontSize = 13.sp,
                color = ColorProvider(day = Color(0xFF9E9E9E), night = Color(0xFF9E9E9E))
            )
        )
    }

    @Composable
    private fun NoTimetableContent() {
        Column {
            Text(
                text = "Jadwal",
                style = TextStyle(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(day = Color(0xFFD4930D), night = Color(0xFFD4930D))
                )
            )
            Spacer(modifier = GlanceModifier.height(4.dp))
            Text(
                text = "Tap to set up timetable",
                style = TextStyle(
                    fontSize = 11.sp,
                    color = ColorProvider(day = Color(0xFF9E9E9E), night = Color(0xFF9E9E9E))
                )
            )
        }
    }

    @Composable
    private fun TodayContent(data: WidgetData.Today) {
        Column {
            Text(
                text = data.dayName,
                style = TextStyle(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(day = Color(0xFF1A1A1A), night = Color(0xFFE0E0E0))
                )
            )
            Spacer(modifier = GlanceModifier.height(2.dp))
            Text(
                text = "${data.periodCount} period${if (data.periodCount != 1) "s" else ""}",
                style = TextStyle(
                    fontSize = 12.sp,
                    color = ColorProvider(day = Color(0xFF9E9E9E), night = Color(0xFF9E9E9E))
                )
            )
            if (data.currentPeriod != null) {
                Spacer(modifier = GlanceModifier.height(6.dp))
                Text(
                    text = "Now: ${data.currentPeriod}",
                    style = TextStyle(
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Medium,
                        color = ColorProvider(day = Color(0xFFD4930D), night = Color(0xFFD4930D))
                    )
                )
            }
            if (data.nextPeriod != null && data.timeUntilNext != null) {
                Spacer(modifier = GlanceModifier.height(3.dp))
                Text(
                    text = "Next: ${data.nextPeriod} (${data.timeUntilNext})",
                    style = TextStyle(
                        fontSize = 10.sp,
                        color = ColorProvider(day = Color(0xFF9E9E9E), night = Color(0xFF9E9E9E))
                    )
                )
            }
        }
    }

    @Composable
    private fun NoClassesContent(data: WidgetData.NoClassesToday) {
        Column {
            Text(
                text = data.dayName,
                style = TextStyle(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(day = Color(0xFF1A1A1A), night = Color(0xFFE0E0E0))
                )
            )
            Spacer(modifier = GlanceModifier.height(2.dp))
            Text(
                text = "No classes today",
                style = TextStyle(
                    fontSize = 12.sp,
                    color = ColorProvider(day = Color(0xFF9E9E9E), night = Color(0xFF9E9E9E))
                )
            )
        }
    }

    @Composable
    private fun ErrorContent(data: WidgetData.Error) {
        Column {
            Text(
                text = "Jadwal",
                style = TextStyle(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(day = Color(0xFFD4930D), night = Color(0xFFD4930D))
                )
            )
            Spacer(modifier = GlanceModifier.height(2.dp))
            Text(
                text = data.message,
                style = TextStyle(
                    fontSize = 12.sp,
                    color = ColorProvider(day = Color(0xFFC62828), night = Color(0xFFEF5350))
                )
            )
        }
    }
}
