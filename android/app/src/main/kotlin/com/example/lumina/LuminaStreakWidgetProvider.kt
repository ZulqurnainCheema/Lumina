package com.example.lumina

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

// Shows the in-app streak card, which the app draws to an image. Until the
// app has run once there is no image, so a plain layout stands in.
class LuminaStreakWidgetProvider : HomeWidgetProvider() {
    private val labelIds = intArrayOf(
        R.id.streak_day_label_0, R.id.streak_day_label_1, R.id.streak_day_label_2,
        R.id.streak_day_label_3, R.id.streak_day_label_4, R.id.streak_day_label_5,
        R.id.streak_day_label_6,
    )
    private val dotIds = intArrayOf(
        R.id.streak_day_dot_0, R.id.streak_day_dot_1, R.id.streak_day_dot_2,
        R.id.streak_day_dot_3, R.id.streak_day_dot_4, R.id.streak_day_dot_5,
        R.id.streak_day_dot_6,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        // One letter per day: r read, s saved by a freeze, m missed, o still open.
        var week = widgetData.getString("week", "mmmmmmo") ?: "mmmmmmo"
        var labels = widgetData.getString("weekLabels", "MTWTFSS") ?: "MTWTFSS"
        var status = widgetData.getString("streakStatus", "") ?: ""

        // The app only writes this data while it is open. If a new day has
        // started since, move the week along so "today" is really today.
        val today = LocalDate.now()
        val daysStale = try {
            ChronoUnit.DAYS.between(
                LocalDate.parse(widgetData.getString("widgetDate", today.toString())),
                today,
            ).toInt().coerceAtLeast(0)
        } catch (error: Exception) {
            0
        }
        if (daysStale > 0) {
            val closed = week.dropLast(1) + if (week.last() == 'o') 'm' else week.last()
            week = (closed + "m".repeat(daysStale - 1) + "o").takeLast(7)
            labels = (6 downTo 0).joinToString("") { offset ->
                today.minusDays(offset.toLong()).dayOfWeek
                    .getDisplayName(TextStyle.SHORT, Locale.getDefault()).take(1)
            }
            status = "Open Lumina to update"
        }

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.lumina_streak_widget).apply {
                setTextViewText(R.id.streak_widget_count, widgetData.getString("streak", "0"))
                setTextViewText(R.id.streak_widget_status, status)
                for (index in 0 until 7) {
                    val labelId = labelIds[index]
                    val dotId = dotIds[index]
                    setTextViewText(labelId, labels.getOrNull(index)?.toString() ?: "")
                    val state = week.getOrNull(index) ?: 'm'
                    setInt(
                        dotId,
                        "setBackgroundResource",
                        when (state) {
                            'r' -> R.drawable.lumina_dot_read
                            'o' -> R.drawable.lumina_dot_open
                            else -> R.drawable.lumina_dot_missed
                        },
                    )
                    setTextViewText(
                        dotId,
                        when (state) {
                            'r' -> "\u2713"
                            's' -> "\u2744"
                            else -> ""
                        },
                    )
                    setTextColor(
                        dotId,
                        if (state == 's') 0xFFABA59B.toInt() else 0xFF11100E.toInt(),
                    )
                }
                // The drawn card shows the day it was made, so it is only used
                // while it is still that day.
                val card = if (daysStale > 0) {
                    null
                } else {
                    widgetData.getString("streakCard", null)
                        ?.let { BitmapFactory.decodeFile(it) }
                }
                if (card != null) {
                    setImageViewBitmap(R.id.streak_widget_image, card)
                    setViewVisibility(R.id.streak_widget_image, View.VISIBLE)
                    setViewVisibility(R.id.streak_widget_fallback, View.INVISIBLE)
                } else {
                    setViewVisibility(R.id.streak_widget_image, View.GONE)
                    setViewVisibility(R.id.streak_widget_fallback, View.VISIBLE)
                }
                setOnClickPendingIntent(
                    R.id.streak_widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("lumina://today"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
