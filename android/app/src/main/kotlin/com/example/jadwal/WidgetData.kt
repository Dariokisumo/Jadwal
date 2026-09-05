package com.example.jadwal

sealed class WidgetData {
    data object Loading : WidgetData()

    data object NoTimetable : WidgetData()

    data class Today(
        val dayName: String,
        val periodCount: Int,
        val currentPeriod: String?,
        val nextPeriod: String?,
        val timeUntilNext: String?
    ) : WidgetData()

    data class NoClassesToday(val dayName: String) : WidgetData()

    data class Error(val message: String) : WidgetData()
}